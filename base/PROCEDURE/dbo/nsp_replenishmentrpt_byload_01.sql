SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_ReplenishmentRpt_ByLoad_01                     */
/* Creation Date: 18-Sept-2004                                          */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: Replensihment Report for IDSTW NIKE Principle due to        */
/*          different Allocation Sorting                                */
/*          The Replenishment is based on the LOC and by Pallet.        */
/* Usage:                                                               */
/*                                                                      */
/* Called By: r_replenishment_report02                                  */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 28-Mar-2003  Shong     Make use of SKU.PickCode for replenishment lot*/
/*                        sorting                                       */
/* 05-Nov-2007  Shong     Hang when printing, change temptable to memory*/
/*                        table                                         */
/************************************************************************/
CREATE PROC [dbo].[nsp_ReplenishmentRpt_ByLoad_01]
				@cLoadKey           NVARCHAR(10)
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
   ,               @n_starttcnt   int

   DECLARE @b_debug int,
		   @c_Packkey  NVARCHAR(10),
		   @c_UOM      NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
		   @n_qtytaken int,
		   @n_SerialNo int,
		   @cFacility  NVARCHAR(5)

   SELECT @n_continue=1, @b_debug = 0

   DECLARE @c_priority  NVARCHAR(5)

   DECLARE @OrderDetail TABLE (
           LOC NVARCHAR(10),
           StorerKey NVARCHAR(15),
           SKU       NVARCHAR(20),
           OpenQty   int )

   DECLARE @REPLENISHMENT TABLE (
          StorerKey      NVARCHAR(15), 
          SKU            NVARCHAR(20), 
          FromLOC        NVARCHAR(10), 
          ToLOC          NVARCHAR(10), 
          Lot            NVARCHAR(10), 
          Id             NVARCHAR(18), 
          Qty            int, 
          QtyMoved       int, 
          QtyInPickLOC   int,
          Priority       NVARCHAR(5), 
          UOM            NVARCHAR(5), 
          PackKey        NVARCHAR(10)
   )
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_CurrentSKU NVARCHAR(20), @c_CurrentStorer NVARCHAR(15),
		      @c_CurrentLOC NVARCHAR(10), @c_CurrentPriority NVARCHAR(5),
		      @n_CurrentFullCase int, @n_CurrentSeverity int,
		      @c_FromLOC NVARCHAR(10), @c_fromlot NVARCHAR(10), @c_fromid NVARCHAR(18),
		      @n_FromQty int, @n_remainingqty int, @n_PossibleCases int ,
		      @n_remainingcases int, @n_OnHandQty int, @n_fromcases int ,
		      @c_ReplenishmentKey NVARCHAR(10), @n_numberofrecs int, @n_limitrecs int,
		      @c_fromlot2 NVARCHAR(10),
		      @b_DoneCheckOverAllocatedLots int,
		      @n_SKULocAvailableQty int,
				@c_CurrentLoadkey NVARCHAR(10), @c_CurrentSectionkey NVARCHAR(10) 

      DECLARE @c_PickCode NVARCHAR(10)

      SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
		      @c_CurrentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),
		      @n_CurrentFullCase = 0   , @n_CurrentSeverity = 9999999 ,
		      @n_FromQty = 0, @n_remainingqty = 0, @n_PossibleCases = 0,
		      @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,
		      @n_limitrecs = 5,
		      @c_CurrentLoadkey = SPACE(10), @c_CurrentSectionkey = SPACE(10)
      
      /* Make a temp version of ORDERDETAIL */
      INSERT INTO @OrderDetail 
		SELECT SKUxLOC.LOC, ORDERDETAIL.StorerKey, ORDERDETAIL.SKU, SUM(OpenQty) AS OpenQty
		FROM ORDERDETAIL (NOLOCK) 
		JOIN SKUxLOC (NOLOCK) ON (ORDERDETAIL.SKU = SKUxLOC.SKU AND ORDERDETAIL.Storerkey = SKUxLOC.Storerkey)
		WHERE Loadkey = @cLoadKey
		AND	Status < '9'
		AND	SKUxLOC.LOC <> '71FAST' 
		GROUP BY SKUxLOC.LOC, ORDERDETAIL.StorerKey, ORDERDETAIL.Sku


      /* Make a temp version of SKUxLOC */
	   SELECT ReplenishmentPriority,
				 ReplenishmentSeverity, 
				 SKU, 
				 Loc AS FromLoc, 
	          Loc, 
				 Storerkey, 
             SPACE(5) AS Facility, 
				 SPACE(10) AS Loadkey,
				 SPACE(10) AS Sectionkey 
      INTO #TempSKUxLOC
      FROM SKUxLOC (NOLOCK)
      WHERE 1=2

      INSERT #TempSKUxLOC
      SELECT 1,
		      ReplenishmentSeverity = SUM(ORDERDETAIL.OpenQty),
		      SL2.SKU,
				SL2.Loc, 
		      '71FAST',
		      ORDERDETAIL.StorerKey,
		      ORDERS.Facility, 
				ORDERS.Loadkey,
				ORDERS.Sectionkey 
      FROM ORDERDETAIL (NOLOCK)
      JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
      JOIN SKU (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.SKU = SKU.SKU)
      JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PACKKey)
      JOIN LOADPLANDETAIL (NOLOCK) ON (ORDERDETAIL.LoadKey = LOADPLANDETAIL.LoadKey 
                                    AND LOADPLANDETAIL.OrderKey = ORDERS.OrderKey)
		JOIN @OrderDetail OD ON (OrderDetail.StorerKey = OD.Storerkey AND OrderDetail.Sku = OD.Sku ) 
		JOIN SKUxLOC SL1 (NOLOCK) ON (ORDERDETAIL.Storerkey = SL1.Storerkey AND ORDERDETAIL.Sku = SL1.Sku 
											AND OD.LOC = SL1.LOC											)
		JOIN SKUxLOC SL2 (NOLOCK) ON (SUBSTRING(ORDERDETAIL.Sku,1,6) = SUBSTRING(SL2.Sku,1,6)
												AND SL1.LOC = SL2.LOC
												AND SL1.Storerkey = SL2.Storerkey)
      WHERE ORDERDETAIL.OpenQty > 0 
      AND   LOADPLANDETAIL.LoadKey = @cLoadKey 
      AND   ORDERDETAIL.LoadKey = @cLoadKey 
      GROUP BY ORDERDETAIL.StorerKey,
			      SL2.SKU,
					SL2.Loc, 
               PACK.CaseCnt, 
			      ORDERS.Facility, 
					ORDERS.Loadkey,
					ORDERS.Sectionkey 

      IF @b_debug = 1
      BEGIN
         SELECT 'TEMPSKUxLOC table'
         SELECT * FROM #TempSKUxLOC
      END

      IF (SELECT COUNT(*) FROM #TempSKUxLOC) > 0 
      BEGIN
         DELETE REPLENISHMENT WHERE ReplenishmentGroup = @cLoadKey
      END

      CREATE TABLE #LOT 
						 (SerialNo   int IDENTITY(1,1),
                    Lot        NVARCHAR(10), 
                    SortDate   NVARCHAR(20) NULL,
                    Qty        int ) 

      SELECT @n_starttcnt = @@TRANCOUNT
      SELECT @c_CurrentSKU = SPACE(20), 
             @c_CurrentStorer = SPACE(15),
             @c_CurrentLOC = SPACE(10),
				 @c_CurrentLoadkey = SPACE(10), 
				 @c_CurrentSectionkey = SPACE(10) 


      WHILE (1=1) -- while 3
      BEGIN
         SET ROWCOUNT 1

         SELECT @c_CurrentStorer = StorerKey
         FROM #TempSKUxLOC
         WHERE StorerKey > @c_CurrentStorer
         ORDER BY StorerKey
            
         IF @@ROWCOUNT = 0
         BEGIN
            SET ROWCOUNT 0
            BREAK
         END

         SET ROWCOUNT 0
         IF @b_debug = 1
         BEGIN
            Print 'Working on @c_CurrentStorer:' + dbo.fnc_RTrim(@c_CurrentStorer)
         END 

         /* Now - for this priority, this severity - find the next LOC row */
         /* that matches */
         SELECT @c_CurrentLOC = SPACE(10)

         WHILE (1=1) -- while 4
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_CurrentStorer = StorerKey ,
                   @c_CurrentLOC = LOC 
            FROM #TempSKUxLOC
            -- Changed by June 18.Oct.04 SOS28517
            -- WHERE SKU > @c_CurrentLOC 
            WHERE LOC > @c_CurrentLOC 
            AND StorerKey = @c_CurrentStorer
            ORDER BY LOC

            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0

	         IF @b_debug = 1
	         BEGIN
	            Print 'Working on @c_CurrentLOC:' + dbo.fnc_RTrim(@c_CurrentLOC) 
	         END 

	         /* Now - for this priority, this severity - find the next SKU row */
	         /* that matches */
	         SELECT @c_CurrentSKU = SPACE(20) 
	         WHILE (1=1) -- while 4
	         BEGIN
	            SET ROWCOUNT 1

	            SELECT @c_CurrentSKU = SKU,
							 @n_CurrentSeverity = ReplenishmentSeverity, 
	                   @cFacility = Facility 
	            FROM #TempSKUxLOC
	            WHERE SKU > @c_CurrentSKU 
	            AND StorerKey = @c_CurrentStorer
					AND LOC = @c_CurrentLOC
	            ORDER BY SKU

	            IF @@ROWCOUNT = 0
	            BEGIN
	               SET ROWCOUNT 0
	               BREAK
	            END
	            SET ROWCOUNT 0
               
		         IF @b_debug = 1
		         BEGIN
		            Print 'Working on @c_CurrentSKU:' + dbo.fnc_RTrim(@c_CurrentSKU) + ' @c_CurrentLOC:' + dbo.fnc_RTrim(@c_CurrentLOC) 
		         END 
		         /* We now have a pickLocation that needs to be replenished! */
		         /* Figure out which Locations in the warehouse to pull this product from */
		         /* End figure out which Locations in the warehouse to pull this product from */
              
	            SELECT @c_FromLOC = SPACE(10),  
	                   @c_fromlot = SPACE(10), 
	                   @c_fromid = SPACE(18),
	                   @n_FromQty = 0, @n_PossibleCases = 0,
	                   @n_remainingqty = @n_CurrentSeverity, -- by jeff, used to calculate qty required per LOT, rather than from SKUxLOC
	                   @c_fromlot2 = SPACE(10),
	                   @b_DoneCheckOverAllocatedLots = 0,
	                   @n_SerialNo = 0

            
	            SELECT @c_PickCode = PickCode
	            FROM  SKU (NOLOCK)
	            WHERE StorerKey = @c_CurrentStorer
	            AND   SKU = @c_CurrentSKU

	            IF dbo.fnc_RTrim(@c_PickCode) IS NOT NULL AND dbo.fnc_RTrim(@c_PickCode) <> ''
	            BEGIN
	               INSERT INTO #LOT (Lot, SortDate, Qty) 
	               EXEC(@c_PickCode + ' N''' + @c_CurrentStorer + ''','
	                                + ' N''' + @c_CurrentSKU + ''','
	                                + ' N''' + @c_CurrentLOC + ''','
	                                + ' N''' + @cFacility + ''','
	                                + ' N''' + @c_fromlot2 + '''' )
	               IF @b_debug = 1
	               BEGIN
	                   print 'EXEC ' + @c_PickCode + ' N''' + dbo.fnc_RTrim(@c_CurrentStorer) + ''','
	                                + ' N''' + dbo.fnc_RTrim(@c_CurrentSKU) + ''','
	                                + ' N''' + dbo.fnc_RTrim(@c_CurrentLOC) + ''','
	                                + ' N''' + dbo.fnc_RTrim(@cFacility) + ''','
	                                + ' N''' + dbo.fnc_RTrim(@c_fromlot2) + ''''
	               END 
	            END

	            IF @b_debug = 1
					BEGIN
						SELECT * FROM #LOT (NOLOCK) 
					END 

	            IF (SELECT COUNT(*) FROM #LOT) = 0
	            BEGIN
	               IF @b_debug = 1
	                  PRINT '1st. Not Lot Available! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' LOC:' + dbo.fnc_RTrim(@c_CurrentLOC)
	               CONTINUE
	            END
	            ELSE
	            BEGIN
	               IF @b_debug = 1
	               BEGIN
	                  PRINT '1st. *** Lot picked from LOTxLOCxID : ' + dbo.fnc_RTrim(@c_fromlot)
	               END
	            END 

	            IF @b_debug = 1
	            BEGIN
	               PRINT '1st. *** Selected Lot: ' + dbo.fnc_RTrim(@c_fromlot)
	            END


	            WHILE 1=1 -- LOT 
	            BEGIN 
	               SET ROWCOUNT 1

	               IF @b_debug = 1
						BEGIN
							PRINT '1st. SerialNo (before) : ' + dbo.fnc_RTrim(@n_SerialNo)
						END 

	               SELECT @c_FromLot = LOT,
	                      @n_SerialNo = SerialNo 
	               FROM   #LOT
	               WHERE  SerialNo > @n_SerialNo 

	               IF @@ROWCOUNT = 0 
	               BEGIN
	                  SET ROWCOUNT 0 
	                  IF @b_debug = 1
	                     PRINT '2nd. Not Lot Available! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' LOC:' + dbo.fnc_RTrim(@c_CurrentLOC)
	                  BREAK
	               END
	               ELSE
	               BEGIN
	                  IF @b_debug = 1
	                  BEGIN
	                     PRINT '2nd. *** Lot picked from LOTxLOCxID=' + dbo.fnc_RTrim(@c_fromlot)
	                  END
	               END 

	               IF @b_debug = 1
	               BEGIN
							PRINT '2nd. SerialNo (after) : ' + dbo.fnc_RTrim(@n_SerialNo)
	                  PRINT '2nd. SELECTed Lot =' + @c_fromlot
							SELECT '@n_remainingqty : ' + CONVERT(CHAR(5), @n_remainingqty)
	               END
	               SET ROWCOUNT 0 

	               SELECT @c_FromLOC = SPACE(10)

	               WHILE (1=1 AND @n_remainingqty > 0) -- LOC 
	               BEGIN
	                  SET ROWCOUNT 1

	                  SELECT @c_FromLOC = LOTxLOCxID.LOC
	                  FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
	                  WHERE LOT = @c_fromlot
	                  AND LOTxLOCxID.LOC = LOC.LOC
	                  AND LOTxLOCxID.LOC > @c_FromLOC
	                AND StorerKey = @c_CurrentStorer
	                  AND SKU = @c_CurrentSKU
	                  AND LOTxLOCxID.LOC = LOC.LOC
	                  AND LOC.LocationFlag <> 'DAMAGE'
	                  AND LOC.LocationFlag <> 'HOLD'
	                  AND LOC.Status <> 'HOLD'
	                  AND LOC.Facility = @cFacility
	                  AND LOTxLOCxID.qty - qtypicked - QtyAllocated > 0
	                  AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
	                  AND LOTxLOCxID.LOC <> @c_CurrentLOC
			            AND LOC.PUTAWAYZONE = 'NIKEA' -- Add by June 28.Oct.04 SOS28855
	                  ORDER BY LOTxLOCxID.LOC

	                  IF @@ROWCOUNT = 0
	                  BEGIN
	                     SET ROWCOUNT 0
	                     IF @b_debug = 1
	                     BEGIN
	                        Print 'No LOC Selected!'
	                     END
	                     BREAK
	                  END

	                  SET ROWCOUNT 0
	                  IF @b_debug = 1
	                  BEGIN
	                     Print 'Location Selected = ' + @c_FromLOC
	                  END
   
	                  SELECT @c_fromid = replicate('Z',18)
	                  WHILE (1=1 AND @n_remainingqty > 0)
	                  BEGIN
	                     SET ROWCOUNT 1
	                     SELECT @c_fromid = ID,
										 @n_OnHandQty = LOTxLOCxID.QTY - QTYPICKED - QtyAllocated
	                     FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
	                     WHERE LOT = @c_fromlot
	                     AND LOTxLOCxID.LOC = LOC.LOC
	                     AND LOTxLOCxID.LOC = @c_FromLOC
	                     AND id < @c_fromid
	                     AND StorerKey = @c_CurrentStorer
	                     AND SKU = @c_CurrentSKU
	                     AND LOC.LocationFlag <> 'DAMAGE'
	                     AND LOC.LocationFlag <> 'HOLD'
	                     AND LOC.Status <> 'HOLD'
	                     AND LOC.Facility = @cFacility
	                     AND LOTxLOCxID.qty - qtypicked - QtyAllocated > 0
	                     AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
	                     AND LOTxLOCxID.LOC <> @c_CurrentLOC
	                     ORDER BY ID DESC

	                     IF @@ROWCOUNT = 0
	                     BEGIN
	                        IF @b_debug = 1
	                        BEGIN
	                           Print 'Stop because No Pallet Found! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_FromLOC
	                           + ' From ID = ' + @c_fromid
	                        END
	                        SET ROWCOUNT 0
	                        BREAK
	                     END

	                  SET ROWCOUNT 0
	                  IF @b_debug = 1
	                  BEGIN
	                     Print 'ID SELECTed:'+ @c_fromid + ' Onhandqty:' + cast(@n_onhandqty as NVARCHAR(10))
	                  END

	                  /* We have a candidate FROM record */
	                  /* Verify that the cANDidate ID is not on HOLD */
	                  /* We could have done this in the SQL statements above */
	                  /* But that would have meant a 5-way join.             */
	                  /* SQL SERVER seems to work best on a maximum of a     */
	                  /* 4-way join.                                        */
	                  IF EXISTS(SELECT * FROM ID (NOLOCK) WHERE ID = @c_fromid
											AND STATUS = 'HOLD')
	                  BEGIN
	                     IF @b_debug = 1
	                     BEGIN
	                        Print 'Stop because Location Status = HOLD! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU + ' ID = ' + @c_fromid
	                     END
	                     BREAK -- Get out of loop, so that next cANDidate can be evaluated
	                  END

	                  /* Verify that the from Location is not overalLOCated in SKUxLOC */
	                  IF EXISTS(SELECT 1 FROM SKUxLOC (NOLOCK)
	                  WHERE StorerKey = @c_CurrentStorer
	                  AND SKU = @c_CurrentSKU
	                  AND LOC = @c_FromLOC
	                  AND QTYEXPECTED > 0
	                  )
	                  BEGIN
	                     IF @b_debug = 1
	                     BEGIN
	                        Print 'Stop because Qty Expected > 0! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
	                     END
	                     BREAK -- Get out of loop, so that next cANDidate can be evaluated
	                  END

	                  /* Verify that the FROM Location is not the */
	                  /* PIECE PICK Location for this product.    */
	                  IF EXISTS(SELECT 1 FROM SKUxLOC (NOLOCK)
	                  WHERE StorerKey = @c_CurrentStorer
	                  AND SKU = @c_CurrentSKU
	                  AND LOC = @c_FromLOC
	                  AND LocationType = 'PICK'
	                  )
	                  BEGIN
	                     IF @b_debug = 1
	                     BEGIN
	                        Print 'Stop because Location Type = PICK! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
	                     END
	                     BREAK -- Get out of loop, so that next cANDidate can be evaluated
	                  END

	                  /* Verify that the FROM Location is not the */
	                  /* CASE PICK Location for this product.     */
	                  IF EXISTS(SELECT 1 FROM SKUxLOC (NOLOCK)
	                  WHERE StorerKey = @c_CurrentStorer
	                  AND SKU = @c_CurrentSKU
	                  AND LOC = @c_FromLOC
	                  AND LocationType = 'CASE'
	                  )
	                  BEGIN
	                     IF @b_debug = 1
	                     BEGIN
	                        Print 'Stop because Location Type = CASE! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
	                     END
	                     BREAK -- Get out of loop, so that next cANDidate can be evaluated
	                  END

		                  /* At this point, get the available qty from  */
		                  /* the SKUxLOC record.                        */
		                  /* If it's less than what was taken from the  */
		                  /* LOTxLOCxID record, then use it.            */
		                  /* How many cases can I get from this record? */
-- 		                  SELECT @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullCase)
		                  SELECT @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentSeverity)

		                  IF @b_debug = 1
		                  BEGIN
		                     Print '@n_OnHandQty  = ' + cast(@n_OnHandQty as NVARCHAR(10))  + ' @n_RemainingQty  =' + cast(@n_RemainingQty as NVARCHAR(10))
		                     Print '@n_possiblecases =' + cast(@n_possiblecases as NVARCHAR(10)) + ' @n_CurrentSeverity = ' + cast(@n_CurrentSeverity as NVARCHAR(10))
		                  END

		                  /* How many do we take? */
		                  IF @n_OnHandQty > @n_RemainingQty
		                  BEGIN
		                     -- Modify by SHONG for full carton only
		                     SELECT @n_FromQty = @n_OnHandQty
		                     SELECT @n_RemainingQty = 0
		                  END
		                  ELSE
		                  BEGIN
		                     -- Modify by shong for full carton only
		                     SELECT @n_FromQty = @n_OnHandQty
		                     SELECT @n_remainingqty = @n_remainingqty - @n_FromQty

		                     IF @b_debug = 1
		                     BEGIN
		                        print 'Checking possible cases AND current full case available - @n_RemainingQty > @n_FromQty'
		                        Print '@n_possiblecases:' + cast(@n_possiblecases as NVARCHAR(10)) + ' @n_CurrentSeverity:' + cast(@n_CurrentSeverity as NVARCHAR(10)) + '@n_FromQty:' + cast(@n_FromQty as NVARCHAR(10))
		                        END
		                     END

		                     IF @n_FromQty > 0
		                     BEGIN
		                        SELECT @c_Packkey = PACK.PackKey,
		                               @c_UOM = PACK.PackUOM3
		                        FROM   SKU (NOLOCK), PACK (NOLOCK)
		                        WHERE  SKU.PackKey = PACK.Packkey
		                        AND    SKU.StorerKey = @c_CurrentStorer
		                        AND    SKU.SKU = @c_CurrentSKU

		                        -- print 'before insert into replenishment'
		                        -- SELECT @n_fromqty 'fromqty', @n_possiblecases 'possiblecases', @n_remainingqty 'remainingqty'
		                        IF @n_continue = 1 or @n_continue = 2
		                        BEGIN
		                           INSERT @REPLENISHMENT (
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
				                           @c_CurrentSKU,
				                           @c_FromLOC,
				                           @c_CurrentLOC,
				                           @c_fromlot,
				                           @c_fromid,
				                           @n_FromQty,
				                           @c_UOM,
				                           @c_Packkey,
				                           @c_CurrentPriority,
				                           0,0)
		                        END
		                        SELECT @n_numberofrecs = @n_numberofrecs + 1
		                     END -- if from qty > 0

		                     IF @b_debug = 1
		                     BEGIN
		                        SELECT @c_CurrentSKU ' SKU', @c_CurrentLOC 'LOC', @c_CurrentPriority 'priority', @n_CurrentSeverity 'full case', @n_CurrentSeverity 'severity'
		                        -- SELECT @n_FromQty 'qty', @c_FromLOC 'fromLOC', @c_fromlot 'from lot', @n_PossibleCases 'possible cases'
		                        SELECT @n_remainingqty '@n_remainingqty', @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU, @c_fromlot 'from lot', @c_fromid
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
	            TRUNCATE TABLE #LOT
	            SET ROWCOUNT 0
	         END -- FOR SKU
	         SET ROWCOUNT 0
         END -- FOR LOC
         SET ROWCOUNT 0
      END -- FOR STORER
      SET ROWCOUNT 0
   END -- IF @n_continue=1 OR @n_continue=2

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      /* Update the column QtyInPickLOC in the Replenishment Table */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         UPDATE @REPLENISHMENT 
               SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked 
         FROM @REPLENISHMENT RP 
         JOIN SKUxLOC (NOLOCK) ON (RP.StorerKey = SKUxLOC.StorerKey AND
		                             RP.SKU = SKUxLOC.SKU AND
		                             RP.toLOC = SKUxLOC.LOC)
      END
   END

   /* Insert Into Replenishment Table Now */
   DECLARE @b_success int,
           @n_err     int,
           @c_errmsg  NVARCHAR(255)

   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM
   FROM   @REPLENISHMENT R
   OPEN CUR1

   FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLOC, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXECUTE nspg_GetKey
		      'REPLENISHKEY',
		      10,
		      @c_ReplenishmentKey OUTPUT,
		      @b_success OUTPUT,
		      @n_err OUTPUT,
		      @c_errmsg OUTPUT

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
         VALUES (@cLoadKey,
		         @c_ReplenishmentKey,
		         @c_CurrentStorer,
		         @c_CurrentSKU,
		         @c_FromLOC,
		         @c_CurrentLOC,
		         @c_FromLot,
		         @c_FromId,
		         @n_FromQty,
		         @c_UOM,
		         @c_PackKey,
		         'N')

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63524   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into live pickdetail table failed.  Preallocated QTY Needs to be Manually Adjusted! (nspOrderProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END -- IF @b_success = 1
      FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLOC, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
   END -- While
   DEALLOCATE CUR1

   -- End Insert Replenishment
   IF @n_continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishmentRpt_Alloc'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
      COMMIT TRAN
      END
      -- RETURN
   END

   SELECT DISTINCT 
			 R.FromLoc, 
          R.Id, 
          R.ToLoc, 
          R.Sku, 
          R.Qty, 
          R.StorerKey, 
          R.Lot, 
          R.PackKey,
          SKU.Descr, 
          R.Priority, 
          L1.PutawayZone, 
          PACK.CASECNT, 
          PACK.PACKUOM1, 
          PACK.PACKUOM3, 
          R.ReplenishmentKey, 
          (LT.Qty - LT.QtyAllocated - LT.QtyPicked) As QtyAvailable, 
          LA.Lottable02, 
          LA.Lottable04, 
			 ORD.Loadkey,
			 ORD.Sectionkey, 
			 l1.loc, l1.facility  
   FROM  SKU (NOLOCK)  
	JOIN	PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
	JOIN	LOTxLOCxID LT (NOLOCK) ON (SKU.Sku = LT.Sku AND SKU.Storerkey = LT.Storerkey)
	JOIN	LOTATTRIBUTE LA (NOLOCK) ON (LT.Sku = LA.Sku AND LT.Storerkey = LA.Storerkey AND LT.LOT = LA.LOT) 
	JOIN	LOC L1 (NOLOCK) ON (LT.Loc = L1.Loc)
	JOIN	ORDERS ORD (NOLOCK) ON (SKU.Storerkey = ORD.Storerkey AND ORD.Loadkey = @cLoadKey)
	JOIN	@OrderDetail OD ON (LT.Loc = OD.Loc)
	RIGHT OUTER JOIN REPLENISHMENT R (NOLOCK) ON (SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey 
											AND LT.Loc = R.FromLoc AND LT.ID = R.ID AND LT.Lot = R.Lot
											AND R.FromLoc = L1.Loc)
   WHERE R.confirmed = 'N'
   AND  L1.Facility = @cFacility
   AND  replenishmentgroup = @cLoadKey 
   ORDER BY L1.PutawayZone, R.FromLoc, R.SKU 
END

GO