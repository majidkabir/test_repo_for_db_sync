SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: nsp_ReplenishmentRpt_PC09                                      */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: Wave Replenishment Report - IDSPH Unilever (ULP)               */
/*          -- Get from IDSPH Production DB and modified                   */
/* Input Parameters:                                                       */
/*                                                                         */
/* Output Parameters:                                                      */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: Replenishment entry's RCM                                    */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author     Ver   Purposes                                  */
/* 20-Jul-2005  MaryVong   1.0   SOS37737 - request by IDSPH - ULP         */
/*                               1) Do not include stocks under curing     */
/*                                  period                                 */
/*                               2) Include new fields: Production Date and*/
/*                                  PalletQty                              */
/*                               3) Do not include QtyOnHold in candidate  */
/*                                  for replenishment                      */
/* 12-May-2009  Leong      1.1   SOS# 136506 - Include LOC sorting         */
/* 05-MAR-2018  Wan01      1.2   WM - Add Functype                         */
/* 05-OCT-2018  CZTENG01   1.3   WM - Add StorerKey, ReplGrp               */
/***************************************************************************/

CREATE PROC  [dbo].[nsp_ReplenishmentRpt_PC09]
    @c_zone01     NVARCHAR(10) 
   ,@c_zone02     NVARCHAR(10) 
   ,@c_zone03     NVARCHAR(10) 
   ,@c_zone04     NVARCHAR(10) 
   ,@c_zone05     NVARCHAR(10) 
   ,@c_zone06     NVARCHAR(10) 
   ,@c_zone07     NVARCHAR(10) 
   ,@c_zone08     NVARCHAR(10) 
   ,@c_zone09     NVARCHAR(10) 
   ,@c_zone10     NVARCHAR(10) 
   ,@c_zone11     NVARCHAR(10) 
   ,@c_zone12     NVARCHAR(10)
   ,@c_storerkey  NVARCHAR(15) = 'ALL' --(CZTENG01)
   ,@c_ReplGrp    NVARCHAR(30) = 'ALL' --(CZTENG01)
 ,  @c_Functype   NCHAR(1) = ''        --(Wan01)  
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
            @c_UOM     NVARCHAR(5)

   DECLARE @n_Qty int   -- SOS 9963 wally 5mar03
   
   SELECT @n_continue=1, @b_debug = 0

   IF @c_zone12 <> '' 
      SELECT @b_debug = CAST( @c_zone12 AS int)


   IF @c_FuncType IN ( 'P' )                                     
   BEGIN
      GOTO QUIT_SP    
   END
   --(Wan01) - END

   DECLARE @c_priority  NVARCHAR(5)
   SELECT StorerKey, SKU, LOC FromLOC, LOC ToLOC, Lot, Id, Qty, Qty QtyMoved, Qty QtyInPickLOC,
      @c_priority Priority, Lot UOM, Lot PackKey
   INTO #REPLENISHMENT
   FROM LOTXLOCXID (NOLOCK)
   WHERE 1 = 2
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_CurrentSku NVARCHAR(20), @c_CurrentStorer NVARCHAR(15),
               @c_CurrentLoc NVARCHAR(10), @c_CurrentPriority NVARCHAR(5),
               @n_CurrentFullcase int, @n_CurrentSeverity int,
               @c_fromLOC NVARCHAR(10), @c_fromlot NVARCHAR(10), @c_fromid NVARCHAR(18),
               @n_FromQty int, @n_RemainingQty int, @n_possiblecases int ,
               @n_remainingcases int, @n_OnHandQty int, @n_fromcases int ,
               @c_ReplenishmentKey NVARCHAR(10), @n_numberofrecs int, @n_limitrecs int,
               @c_fromlot2 NVARCHAR(10),
               @b_DoneCheckOverAllocatedLots int,
               @n_SKULOCavailableQty int
      SELECT @c_CurrentSku = SPACE(20), @c_CurrentStorer = SPACE(15),
               @c_CurrentLoc = SPACE(10), @c_CurrentPriority = SPACE(5),
               @n_CurrentFullcase = 0   , @n_CurrentSeverity = 9999999 ,
               @n_FromQty = 0, @n_RemainingQty = 0, @n_possiblecases = 0, 
               @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,                 
               @n_limitrecs = 5
   
      /* Make a temp version of SKUxLOC */
      SELECT ReplenishmentPriority, ReplenishmentSeverity ,StorerKey,
      SKU, LOC, ReplenishmentCasecnt
      INTO #TempSKUxLOC
      FROM SKUxLOC (NOLOCK)
      WHERE 1=2
   
      IF (@c_zone02 = 'ALL')
      BEGIN
         INSERT #TempSKUxLOC
            SELECT ReplenishmentPriority, ReplenishmentSeverity ,StorerKey,
            SKU, SKUxLOC.LOC, ReplenishmentCasecnt
            FROM SKUxLOC (NOLOCK), LOC (NOLOCK)
            WHERE SKUxLOC.LOC = LOC.LOC
            AND   LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')   -- SOS37737
            AND   (SKUxLOC.Locationtype = 'PICK' OR SKUxLOC.Locationtype = 'CASE')
            AND   ReplenishmentSeverity > 0
            AND   SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum
            AND   LOC.FACILITY = @c_Zone01
            AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') --(Wan01)
      END
      ELSE
      BEGIN
         INSERT #TempSKUxLOC
            SELECT ReplenishmentPriority, ReplenishmentSeverity ,StorerKey,
            SKUxLOC.SKU, LOC.LOC, ReplenishmentCasecnt
            FROM SKUxLOC (NOLOCK), LOC (NOLOCK)
            WHERE SKUxLOC.LOC = LOC.LOC
            AND   LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND   (SKUxLOC.Locationtype = 'PICK' OR SKUxLOC.Locationtype = 'CASE')
            AND   ReplenishmentSeverity > 0
            AND   SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum
            AND   LOC.FACILITY = @c_Zone01
            AND   LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, 
                                    @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
            AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') --(Wan01)
      END
   
      -- SOS 9963: wally 5mar03
      -- create a temporary lotxlocxid for processing to avoid suggesting same record twice
      -- for sku with multiple pick location
      select lli.*
      into #lotxlocxid
      from lotxlocxid lli (nolock) join #tempskuxloc t (nolock)
          on lli.StorerKey = t.StorerKey
            and lli.sku = t.sku
      where lli.Qty > 0
          
      WHILE (1=1)
      BEGIN
         SET ROWCOUNT 1
         SELECT @c_CurrentPriority = ReplenishmentPriority
         FROM #TempSKUxLOC
         WHERE ReplenishmentPriority > @c_CurrentPriority
         AND   ReplenishmentCasecnt > 0
         ORDER BY ReplenishmentPriority
      
            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0
      
         /* Loop through SKUxLOC for the currentSKU, current stORer */
         /* to pickup the next severity */
         SELECT @n_CurrentSeverity = 999999999    
         WHILE (1=1)
         BEGIN
            SET ROWCOUNT 1
            SELECT @n_CurrentSeverity = ReplenishmentSeverity
            FROM #TempSKUxLOC
            WHERE ReplenishmentSeverity < @n_CurrentSeverity
            AND ReplenishmentPriority = @c_CurrentPriority
            AND  ReplenishmentCasecnt > 0
            ORDER BY ReplenishmentSeverity DESC
            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0
      
            /* Now - for this priority, this severity - find the next storer row */
            /* that matches */
            SELECT @c_CurrentSku = SPACE(20), @c_CurrentStorer = SPACE(15), @c_CurrentLoc = SPACE(10)
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1
               SELECT @c_CurrentStorer = StorerKey
               FROM #TempSKUxLOC
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
      
               /* Now - for this priority, this severity - find the next SKU row */
               /* that matches */
               SELECT @c_CurrentSku = SPACE(20),
               @c_CurrentLoc = SPACE(10)
               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_CurrentSku = SKU,
                  @c_CurrentLoc = LOC,
                  @n_CurrentFullcase = ReplenishmentCasecnt
                  FROM #TempSKUxLOC
                  -- SOS 9963: wally > to handle multiple pick loc for 1 sku
                  WHERE SKU + LOC > @c_CurrentSku + @c_CurrentLoc
                  AND StorerKey = @c_CurrentStorer
                  AND ReplenishmentSeverity = @n_CurrentSeverity
                  AND ReplenishmentPriority = @c_CurrentPriority
                  ORDER BY SKU, LOC -- SOS# 136506
   
                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET ROWCOUNT 0
                     BREAK
                  END
                  SET ROWCOUNT 0
   
                  -- to include shelflife of an item
                  -- for Unilever Philippines
                  -- by Wally 05.sep.2001
                  DECLARE @n_ShelfLife int,
                     @n_SkuBusr2 int -- SOS37737
   
                  SELECT @n_ShelfLife = ISNULL(ShelfLife, 0),
                     -- SOS37737
                     @n_SkuBusr2 = CASE WHEN ISNUMERIC(SKU.BUSR2) = 1 THEN CAST(SKU.BUSR2 as int) ELSE 0 END
                  FROM Sku (NOLOCK)
                  WHERE Sku = @c_CurrentSku
                  AND StorerKey = @c_CurrentStorer
   
                  /* We now have a pickLOCation that needs to be replenished! */
                  /* Figure out which LOCations in the warehouse to pull this product from */
                  /* End figure out which LOCations in the warehouse to pull this product from */                              
                  
                  SELECT @c_fromLOC = SPACE(10),  @c_fromlot = SPACE(10), @c_fromid = SPACE(18), 
                  @n_FromQty = 0, @n_possiblecases = 0,
                  @n_RemainingQty = @n_CurrentSeverity * @n_CurrentFullcase,
                  @n_remainingcases = @n_CurrentSeverity,
                  @c_fromlot2 = SPACE(10),
                  @b_DoneCheckOverAllocatedLots = 0                                     
                      
                  WHILE (1=1)
                  BEGIN
                     /* See if there are any lots where the qty is OverAllocated... */
                     /* if Yes then uses this lot first... */
                     -- That means that the last try at this section of code was successful therefore try again.
                     IF @b_DoneCheckOverAllocatedLots = 0 
                     BEGIN
                        IF @c_zone02 = 'ALL'
                        BEGIN
                           SET ROWCOUNT 1
                              SELECT @c_fromlot2 = LOTxLOCxID.LOT 
                           FROM #lotxlocxid LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK),
                                    LOT (NOLOCK) -- SOS37737 Added LOT
                           WHERE LOTxLOCxID.LOT > @c_fromlot2
                              AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                              AND LOTxLOCxID.SKU = @c_CurrentSku
                              AND LOTxLOCxID.LOC = LOC.LOC
                              AND LOC.LocationFlag <> 'DAMAGE'
                              AND LOC.LocationFlag <> 'HOLD'
                              AND LOTxLOCxID.QtyExpected > 0
                              AND LOTxLOCxID.LOC = @c_CurrentLoc
                              AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                              -- SOS37737 -Start
                              AND LOTxLOCxID.LOT = LOT.LOT
                              AND LOT.Status = 'OK'   
                              AND GetDate() > DATEADD (Day, @n_SkuBusr2, LOTATTRIBUTE.Lottable04)           
                              -- AND (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR
                              --       lotattribute.lottable03 = 'U' OR
                              --       lotattribute.lottable03 = '')
                              -- SOS37737 -End 
                           AND  LOC.FACILITY = @c_Zone01
                           ORDER BY DATEADD(Day, @n_ShelfLife, LOTTABLE04), LOTTABLE05
                        END
                        ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot2 = LOTxLOCxID.LOT 
                           FROM #lotxlocxid LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK),
                                 LOT (NOLOCK) -- SOS37737 Added LOT
                           WHERE LOTxLOCxID.LOT > @c_fromlot2
                              AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                              AND LOTxLOCxID.SKU = @c_CurrentSku
                              AND LOTxLOCxID.LOC = LOC.LOC
                              -- SOS37737 -Start
                              AND LOC.LocationFlag <> 'DAMAGE'
                              AND LOC.LocationFlag <> 'HOLD'
                              -- SOS37737 -End
                              AND LOTxLOCxID.QtyExpected > 0
                              AND LOTxLOCxID.LOC = @c_CurrentLoc
                              AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                              -- SOS37737 -Start
                              AND LOTxLOCxID.LOT = LOT.LOT
                              AND LOT.Status = 'OK'   
                              AND GetDate() > DATEADD (Day, @n_SkuBusr2, LOTATTRIBUTE.Lottable04)
                              -- AND (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR
                              --        lotattribute.lottable03 = 'U' OR
                              --        lotattribute.lottable03 = '')
                              -- SOS37737 -End 
                              AND LOC.FACILITY = @c_Zone01
                              -- SOS37737
                              AND LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, 
                                                   @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                           ORDER BY DATEADD(Day, @n_ShelfLife, LOTTABLE04), LOTTABLE05
                        END     
                        IF @@ROWCOUNT = 0
                        BEGIN
                           SELECT @b_DoneCheckOverAllocatedLots = 1
                           SELECT @c_fromlot = ''
                        END
                        ELSE SELECT @b_DoneCheckOverAllocatedLots = 1
                     END --IF @b_DoneCheckOverAllocatedLots = 0
               
                     /* End see if there are any lots where the Qty is overalLOCated... */
                     SET ROWCOUNT 0
                     /* If there are not lots overalLOCated in the candidate LOCation, simply pull lots into the LOCation by lot # */
                     IF @b_DoneCheckOverAllocatedLots = 1
                     BEGIN                      
                        /* Select any lot if no lot was over alLOCated */
                        IF @c_zone02 = 'ALL'
                        BEGIN      
                           SET ROWCOUNT 1
                           SELECT @c_fromlot = LOTxLOCxID.LOT
                           FROM #lotxlocxid LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK),
                                 LOT (NOLOCK) -- SOS37737 Added LOT
                           WHERE LOTxLOCxID.LOT > @c_fromlot
                              AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                              AND LOTxLOCxID.SKU = @c_CurrentSku
                              AND LOTxLOCxID.LOC = LOC.LOC
                              AND LOC.LocationFlag <> 'DAMAGE'
                              AND LOC.LocationFlag <> 'HOLD'
                              AND LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0
                              AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND 
                              AND LOTxLOCxID.LOC <> @c_CurrentLoc
                              AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                              -- SOS37737 -Start
                              AND LOTxLOCxID.LOT = LOT.LOT
                              AND LOT.Status = 'OK'   
                              AND GetDate() > DATEADD (Day, @n_SkuBusr2, LOTATTRIBUTE.Lottable04)
                              -- AND (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR
                              --        lotattribute.lottable03 = 'U' OR
                              --        lotattribute.lottable03 = '')
                              -- SOS37737 -End 
                              AND LOC.FACILITY = @c_Zone01
                           ORDER BY DATEADD(Day, @n_ShelfLife, LOTTABLE04), LOTTABLE05
                        END
                        ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot = LOTxLOCxID.LOT
                           FROM #lotxlocxid LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK),
                                 LOT (NOLOCK) -- SOS37737 Added LOT
                           WHERE LOTxLOCxID.LOT > @c_fromlot
                              AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                              AND LOTxLOCxID.SKU = @c_CurrentSku
                              AND LOTxLOCxID.LOC = LOC.LOC
                              AND LOC.LocationFlag <> 'DAMAGE'
                              AND LOC.LocationFlag <> 'HOLD'
                              AND LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0
                              AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND 
                              AND LOTxLOCxID.LOC <> @c_CurrentLoc
                              AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                              -- SOS37737 -Start
                              AND LOTxLOCxID.LOT = LOT.LOT
                              AND LOT.Status = 'OK'   
                              AND GetDate() > DATEADD (Day, @n_SkuBusr2, LOTATTRIBUTE.Lottable04)
                              -- AND (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR
                              --        lotattribute.lottable03 = 'U' OR
                              --        lotattribute.lottable03 = '')
                              -- SOS37737 -End 
                              AND LOC.FACILITY = @c_Zone01
                              -- SOS37737
                              AND LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, 
                                                   @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                           ORDER BY DATEADD(Day, @n_ShelfLife, LOTTABLE04), LOTTABLE05
                        END
                        IF @@ROWCOUNT = 0
                        BEGIN
                           IF @b_debug = 1
                           SELECT 'Not Lot Available! SKU= ' + @c_CurrentSku + ' LOC=' + @c_CurrentLoc, 'LOT=' + @c_fromlot
                           SET ROWCOUNT 0
                           BREAK
                        END
                        SET ROWCOUNT 0
                     END
                     ELSE
                     BEGIN
                        SELECT @c_fromlot = @c_fromlot2
                     END -- IF @b_DoneCheckOverAllocatedLots = 1
                     SET ROWCOUNT 0
                        
                     SELECT @c_fromLOC = SPACE(10)
                     WHILE (1=1 AND @n_RemainingQty > 0)
                     BEGIN
                        IF @c_zone02 = 'ALL'
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromLOC = LOTxLOCxID.LOC
                           FROM #lotxlocxid LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                           WHERE LOT = @c_fromlot
                           AND LOTxLOCxID.LOC = LOC.LOC                                             
                           AND LOTxLOCxID.LOC > @c_fromLOC
                           AND StorerKey = @c_CurrentStorer
                           AND SKU = @c_CurrentSku
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LocationFlag <> 'DAMAGE'
                           AND LOC.LocationFlag <> 'HOLD'
                           AND LOTxLOCxID.Qty - QtyPicked - QtyAllocated > 0
                           AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND 
                           AND LOTxLOCxID.LOC <> @c_CurrentLoc
                           AND LOC.FACILITY = @c_Zone01
                           ORDER BY LOTxLOCxID.LOC
                        END
                        ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromLOC = LOTxLOCxID.LOC
                           FROM #lotxlocxid LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                           WHERE LOT = @c_fromlot
                           AND LOTxLOCxID.LOC = LOC.LOC                                             
                           AND LOTxLOCxID.LOC > @c_fromLOC
                           AND StorerKey = @c_CurrentStorer
                           AND SKU = @c_CurrentSku
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LocationFlag <> 'DAMAGE'
                           AND LOC.LocationFlag <> 'HOLD'
                           AND LOTxLOCxID.Qty - QtyPicked - QtyAllocated > 0
                           AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND 
                           AND LOTxLOCxID.LOC <> @c_CurrentLoc
                           AND LOC.FACILITY = @c_Zone01
                           -- SOS37737
                           AND LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, 
                                                @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                           ORDER BY LOTxLOCxID.LOC
                        END
                        IF @@ROWCOUNT = 0
                        BEGIN
                           SET ROWCOUNT 0
                           BREAK
                        END
                        SET ROWCOUNT 0
                        SELECT @c_fromid = replicate('Z',18)
                        WHILE (1=1 AND @n_RemainingQty > 0)
                        BEGIN
                           IF @c_zone02 = 'ALL'
                           BEGIN
                              SET ROWCOUNT 1
                              SELECT @c_fromid = ID,
                              @n_OnHandQty = LOTxLOCxID.Qty - QtyPicked - QtyAllocated
                              FROM #lotxlocxid LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                              WHERE LOT = @c_fromlot
                                 AND LOTxLOCxID.LOC = LOC.LOC
                                 AND LOTxLOCxID.LOC = @c_fromLOC
                                 AND id < @c_fromid
                                 AND StorerKey = @c_CurrentStorer
                                 AND SKU = @c_CurrentSku
                                 AND  LOC.LocationFlag <> 'DAMAGE'
                                 AND  LOC.LocationFlag <> 'HOLD'
                                 AND LOTxLOCxID.Qty - QtyPicked - QtyAllocated > 0
                                 AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a ocation that needs stuff to satisfy existing demAND 
                                 AND LOTxLOCxID.LOC <> @c_CurrentLoc
                              AND LOC.FACILITY = @c_Zone01
                              ORDER BY ID DESC
                           END
                           ELSE
                           BEGIN
                              SET ROWCOUNT 1
                              SELECT @c_fromid = ID,
                              @n_OnHandQty = LOTxLOCxID.Qty - QtyPicked - QtyAllocated
                              FROM #lotxlocxid LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                              WHERE LOT = @c_fromlot
                                 AND LOTxLOCxID.LOC = LOC.LOC
                                 AND LOTxLOCxID.LOC = @c_fromLOC
                                 AND id < @c_fromid
                                 AND StorerKey = @c_CurrentStorer
                                 AND SKU = @c_CurrentSku
                                 AND LOC.LocationFlag <> 'DAMAGE'
                                 AND LOC.LocationFlag <> 'HOLD'
                                 AND LOTxLOCxID.Qty - QtyPicked - QtyAllocated > 0
                                 AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND 
                                 AND LOTxLOCxID.LOC <> @c_CurrentLoc
                                 AND LOC.FACILITY = @c_Zone01
                                 -- SOS37737
                                 AND LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, 
                                                      @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)

                              ORDER BY ID DESC 
                           END
                           IF @@ROWCOUNT = 0
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because No Pallet Found! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSku + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_fromLOC 
                                    + ' From ID = ' + @c_fromid
                              END
                              SET ROWCOUNT 0
                              BREAK 
                           END   
                           SET ROWCOUNT 0
                           /* We have a candidate from record */
                           /* Verify that the candidate ID is not on HOLD */
                           /* We could have done this in the SQL statements above */
                           /* But that would have meant a 5-way join.             */
                           /* SQL SERVER seems to work best on a maximum of a     */
                           /* 4-way join.                                         */
                           IF EXISTS(SELECT * FROM ID (NOLOCK) WHERE ID = @c_fromid AND STATUS = 'HOLD')
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because LOCation Status = HOLD! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSku + ' ID = ' + @c_fromid
                              END
                              BREAK -- Get out of loop, so that next candidate can be evaluated
                           END                                                                                                      
                           /* Verify that the from Location is not overallocated in SKUxLOC */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                           WHERE StorerKey = @c_CurrentStorer
                              AND SKU = @c_CurrentSku
                              AND LOC = @c_fromLOC
                              AND QtyExpected > 0)
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because Qty Expected > 0! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSku
                              END
                              BREAK -- Get out of loop, so that next candidate can be evaluated
                           END
                           /* Verify that the from location is not the */
                           /* PIECE PICK Location for this product.    */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                           WHERE StorerKey = @c_CurrentStorer
                              AND SKU = @c_CurrentSku
                              AND LOC = @c_fromLOC
                              AND Locationtype = "PICK")
                           BEGIN 
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because LOCation Type = PICK! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSku
                              END
                              BREAK -- Get out of loop, so that next cANDidate can be evaluated                                                  
                           END
                           /* Verify that the from Location is not the */
                           /* CASE PICK Location for this product.     */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                           WHERE StorerKey = @c_CurrentStorer
                              AND SKU = @c_CurrentSku
                              AND LOC = @c_fromLOC
                              AND Locationtype = "CASE")
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because LOCation Type = CASE! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSku
                              END
                              BREAK -- Get out of loop, so that next candidate can be evaluated                                                  
                           END
                           /* At this point, get the available qty from */
                           /* the SKUxLOC record.                       */
                           /* If it's less than what was taken from the */
                           /* lotxlocxid record, then use it.           */
                           SELECT @n_SKULOCavailableQty = Qty - QtyAllocated - QtyPicked
                           FROM SKUxLOC (NOLOCK)
                           WHERE StorerKey = @c_CurrentStorer
                              AND SKU = @c_CurrentSku
                              AND LOC = @c_fromLOC
                           IF @n_SKULOCavailableQty < @n_OnHandQty
                           BEGIN
                              SELECT @n_OnHandQty = @n_SKULOCavailableQty
                           END
                           /* How many cases can I get from this record? */
                           SELECT @n_possiblecases = floOR(@n_OnHandQty / @n_CurrentFullcase)
         
                           /* How many do we take? */
                           IF @n_OnHandQty > @n_RemainingQty
                           BEGIN
                              SELECT @n_FromQty = @n_RemainingQty,
                              -- @n_RemainingQty = @n_RemainingQty - (@n_remainingcases * @n_CurrentFullcase),
                              @n_RemainingQty = 0
                           END
                           ELSE  
                           BEGIN
                              SELECT @n_FromQty = @n_OnHandQty,
                                 @n_RemainingQty = @n_RemainingQty - @n_OnHandQty
                                 -- @n_remainingcases =  @n_remainingcases - @n_possiblecases
                           END
                           IF @n_FromQty > 0
                           BEGIN
                              SELECT @c_Packkey = PACK.PackKey,
                                    @c_UOM = PACK.PackUOM3
                              FROM SKU (NOLOCK), PACK (NOLOCK)
                              WHERE SKU.PackKey = PACK.Packkey
                                AND SKU.StorerKey = @c_CurrentStorer
                                AND SKU.SKU = @c_CurrentSku

                              IF @n_continue = 1 OR @n_continue = 2
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
                                          PriORity,
                                          QtyMoved,
                                          QtyInPickLOC) 
                                          VALUES (
                                          @c_CurrentStorer, 
                                          @c_CurrentSku, 
                                          @c_fromLOC, 
                                          @c_CurrentLoc, 
                                          @c_fromlot,
                                          @c_fromid,
                                          @n_FromQty,
                                          @c_UOM,
                                          @c_Packkey,
                                          @c_CurrentPriority,
                                          0,0)                    
                              END
                              SELECT @n_numberofrecs = @n_numberofrecs + 1
         
                              -- SOS 9963: wally 5mar03
                              -- create a temporary lotxlocxid for processing to avoid suggesting same record twice
                              -- for sku with multiple pick location
                              -- clean up #lotxlocxid of those used records
                              -- start
                              select @n_Qty = Qty
                              from #lotxlocxid
                              where lot = @c_fromlot
                                 and loc = @c_fromloc
                                 and id = @c_fromid
                                 and StorerKey = @c_CurrentStorer
                                 and sku = @c_CurrentSku

                              if @n_FromQty > @n_Qty
                                 update #lotxlocxid
                                 set Qty = (@n_FromQty - @n_Qty)    
                                 where lot = @c_fromlot
                                    and loc = @c_fromloc
                                    and id = @c_fromid
                                    and StorerKey = @c_CurrentStorer
                                    and sku = @c_CurrentSku
                              else
                                 delete #lotxlocxid
                                 where lot = @c_fromlot
                                    and loc = @c_fromloc
                                    and id = @c_fromid
                                    and StorerKey = @c_CurrentStorer
                                    and sku = @c_CurrentSku
                              -- end
                           END -- IF @n_FromQty > 0
                              
                           IF @b_debug = 1 
                           BEGIN
                           select @c_CurrentSku ' SKU', @c_CurrentLoc 'LOC', @c_CurrentPriority 'priORity', @n_CurrentFullcase 'full case', @n_CurrentSeverity 'severity'
                                 -- select @n_FromQty 'Qty', @c_fromLOC 'fromLOC', @c_fromlot 'from lot', @n_possiblecases 'possible cases'
                              select @n_RemainingQty '@n_RemainingQty', @c_CurrentLoc + ' SKU = ' + @c_CurrentSku, @c_fromlot 'from lot', @c_fromid
                           END
                           IF @c_fromid = '' OR @c_fromid IS NULL OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromId)) = ''
                           BEGIN
                              -- SELECT @n_RemainingQty=0   
                              BREAK
                           END
                        END -- SCAN LOT FOR ID
                        SET ROWCOUNT 0
                     END -- SCAN LOT FOR LOC                                   
                     SET ROWCOUNT 0
                  END -- SCAN LOT FOR LOT
                  SET ROWCOUNT 0
               END -- FOR SKU
               SET ROWCOUNT 0                         
            END -- FOR STORER
            SET ROWCOUNT 0
         END -- FOR SEVERITY
         SET ROWCOUNT 0
      END  -- (WHILE 1=1 ON SKUxLOC FOR PRIORITY )
      SET ROWCOUNT 0
   END
         
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      /* Update the column QtyInPickLOC in the Replenishment Table */
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         UPDATE #REPLENISHMENT SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked
         FROM SKUxLOC (NOLOCK)
         WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey AND
         #REPLENISHMENT.SKU = SKUxLOC.SKU AND
         #REPLENISHMENT.toLOC = SKUxLOC.LOC 
      END
   END
   
   /* Insert Into Replenishment Table Now */
   DECLARE @b_success int,
   @n_err     int,
   @c_errmsg  NVARCHAR(255)
   
   DECLARE CUR1 CURSOR for 
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.PriORity, R.UOM
   FROM #REPLENISHMENT R
   
   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromID, @c_CurrentLoc, @c_CurrentSku, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_priority, @c_UOM
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXECUTE nspg_GetKey
      "REPLENISHKEY",
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
      FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromID, @c_CurrentLoc, @c_CurrentSku, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_priority, @c_UOM
   END -- While
   DEALLOCATE CUR1
   -- End Insert Replenishment
   
   --(Wan01) - START
   DROP TABLE #lotxlocxid -- SOS 9963: wally 5mar03

   QUIT_SP:
      IF @c_FuncType IN ( 'G' )                                     
      BEGIN
         RETURN
      END
   --(Wan01) - END

      IF ( @c_zone02 = 'ALL')
      BEGIN             
         SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, 
         SKU.Descr, R.PriORity, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey,
         PACK.Pallet, LOTATTRIBUTE.Lottable04 -- SOS37737
         FROM  REPLENISHMENT R, SKU (NOLOCK), LOC (NOLOCK), PACK (NOLOCK), -- Pack table added by Jacob Date Jan 03, 2001
               LOTATTRIBUTE (NOLOCK) -- SOS37737
         WHERE SKU.Sku = R.Sku 
         AND   SKU.StorerKey = R.StorerKey
         AND   LOC.Loc = R.ToLoc
         AND   SKU.PackKey = PACK.PackKey
         AND   LOTATTRIBUTE.LOT = R.LOT   -- SOS37737
         AND   R.Confirmed = 'N'
         AND   LOC.FACILITY = @c_Zone01
         AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)
         AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)
         ORDER BY LOC.PutawayZone, R.PriORity
      END
      ELSE
      BEGIN
         SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, 
         SKU.Descr, R.PriORity, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey,
         PACK.Pallet, LOTATTRIBUTE.Lottable04 -- SOS37737
         FROM  REPLENISHMENT R, SKU (NOLOCK), LOC (NOLOCK), PACK (NOLOCK), -- Pack table added by Jacob. Date: Jan 03, 2001
               LOTATTRIBUTE (NOLOCK) -- SOS37737
         WHERE SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
         AND   LOC.Loc = R.ToLoc
         AND   SKU.PackKey = PACK.PackKey
         AND   LOTATTRIBUTE.LOT = R.LOT   -- SOS37737
         AND   R.Confirmed = 'N'
         AND   LOC.FACILITY = @c_Zone01
         AND   LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, 
                                 @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)
         AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)
         ORDER BY LOC.PutawayZone, R.PriORity
      END
END


GO