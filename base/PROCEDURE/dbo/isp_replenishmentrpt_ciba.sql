SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_ReplenishmentRpt_Ciba                          */
/* Creation Date: 16-Jan-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Ting Tuck Lung                                           */
/*                                                                      */
/* Purpose: Taiwan Ciba Replenishment Report                            */
/*                                                                      */
/*                                                                      */
/* Called By: Replenishment Report                                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 16-Jan-2007  Ting       Amend from nsp_ReplenishmentRpt_PC08         */
/*                         Add expiry date for Ciba                     */ 
/* 27-Apr-2010  NJOW01     213125 - Add Lottable02                      */
/* 18-JAN-2019  Wan01    1.2   WM - Add Storerkey, ReplCgrp & Functype  */
/************************************************************************/
CREATE PROC [dbo].[isp_ReplenishmentRpt_Ciba]
               @c_zone01      NVARCHAR(10)
,              @c_zone02      NVARCHAR(10)
,              @c_zone03      NVARCHAR(10)
,              @c_zone04      NVARCHAR(10)
,              @c_zone05      NVARCHAR(10)
,              @c_zone06      NVARCHAR(10)
,              @c_zone07      NVARCHAR(10)
,              @c_zone08      NVARCHAR(10)
,              @c_zone09      NVARCHAR(10)
,              @c_zone10      NVARCHAR(10)
,              @c_zone11      NVARCHAR(10)
,              @c_zone12      NVARCHAR(10)
,              @c_storerkey   NVARCHAR(15) = 'ALL' --(Wan01)
,              @c_ReplGrp     NVARCHAR(30) = 'ALL' --(Wan01)
,              @c_Functype    NCHAR(1)     = ''    --(Wan01)   
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
   @c_UOM     NVARCHAR(10)  -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
   , @n_FullPallet int
   , @n_PalletCnt  int 

   SELECT @n_continue=1,
   @b_debug = 0

   IF @c_zone12 = '1'
   BEGIN
      SELECT @b_debug = CAST( @c_zone12 AS int)
      SELECT @c_zone12 = ''
   END
   
   --(Wan01) -- START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
      
   IF @c_Functype = 'P'                            
   BEGIN
      GOTO QUIT_SP
   END
   --(Wan01) -- END

   DECLARE @c_priority  NVARCHAR(5)
   SELECT StorerKey, SKU, LOC FromLOC, LOC ToLOC, Lot, Id, Qty, Qty QtyMoved, Qty QtyInPickLOC,
   @c_priority Priority, Lot UOM, Lot PackKey
   INTO #REPLENISHMENT
   FROM LOTXLOCXID (NOLOCK)
   WHERE 1 = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_CurrentSKU NVARCHAR(20), @c_CurrentStorer NVARCHAR(15),
      @c_CurrentLoc NVARCHAR(10), @c_CurrentPriority NVARCHAR(5),
      @n_currentfullcase int, @n_CurrentSeverity int,
      @c_FromLOC NVARCHAR(10), @c_fromlot NVARCHAR(10), @c_fromid NVARCHAR(18),
      @n_FromQty int, @n_remainingqty int, @n_possiblecases int ,
      @n_remainingcases int, @n_OnHandQty int, @n_fromcases int ,
      @c_ReplenishmentKey NVARCHAR(10), @n_numberofrecs int, @n_limitrecs int,
      @c_fromlot2 NVARCHAR(10),
      @b_DoneCheckOverAllocatedLots int,
      @n_SKULOCavailableqty int,
      @c_hostwhcode NVARCHAR(10) -- sos 2199
      SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
      @c_CurrentLoc = SPACE(10), @c_CurrentPriority = SPACE(5),
      @n_currentfullcase = 0   , @n_CurrentSeverity = 9999999 ,
      @n_FromQty = 0, @n_remainingqty = 0, @n_possiblecases = 0,
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
         SELECT ReplenishmentPriority,
         ReplenishmentSeverity = QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated )),
         SKUxLOC.StorerKey,
         SKUxLOC.SKU,
         SKUxLOC.LOC,
         ReplenishmentCasecnt 
         FROM SKUxLOC (NOLOCK), LOC (NOLOCK), SKU (NOLOCK)
         WHERE  (SKUxLOC.LOCationtype = 'PICK' or SKUxLOC.LOCationtype = 'CASE')
         AND  SKUxLOC.LOC = LOC.LOC
         AND  LOC.FACILITY = @c_Zone01
         AND  SKU.StorerKey = SKUxLOC.StorerKey
         AND  SKU.SKU = SKUxLOC.SKU
         AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
         AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') --(Wan01)  
         -- AND  SKUxLOC.SKU = '13274299'
         -- AND  SKU.SUSR3 = 'UTL'
         -- AND  SKUxLOC.QtyExpected > 0
      END
      ELSE
      BEGIN
         INSERT #TempSKUxLOC
         SELECT   ReplenishmentPriority,
         ReplenishmentSeverity = QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated )),
         SKUxLOC.StorerKey,
         SKUxLOC.SKU,
         SKUxLOC.LOC,
         ReplenishmentCasecnt 
         FROM SKUxLOC (NOLOCK), LOC (NOLOCK), SKU (NOLOCK)
         WHERE  (SKUxLOC.LOCationtype = 'PICK' or SKUxLOC.LOCationtype = 'CASE')
         AND  SKUxLOC.LOC = LOC.LOC
         AND  LOC.FACILITY = @c_Zone01
         AND  SKU.StorerKey = SKUxLOC.StorerKey
         AND  SKU.SKU = SKUxLOC.SKU
         AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
         -- AND  SKU.SUSR3 = 'UTL'
         AND  LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') --(Wan01)  
         -- AND  SKUxLOC.QtyExpected > 0
      END
-- Remarked by June 18.Nov.04 : SOS29580
--    SELECT @c_CurrentStorer = 'UTL'
      SET ROWCOUNT 0
      /* Loop through SKUxLOC for the currentSKU, current storer */
      /* to pickup the next severity */
      SELECT @c_CurrentSKU = SPACE(20),
             @c_CurrentLoc = SPACE(10)
      WHILE (1=1)
      BEGIN
         SET ROWCOUNT 1
         SELECT @c_CurrentStorer = StorerKey ,
         @c_CurrentSKU = SKU,
         @c_CurrentLoc = LOC,
         @n_currentfullcase = ReplenishmentCasecnt,
         @n_CurrentSeverity = ReplenishmentSeverity
         FROM #TempSKUxLOC
         WHERE SKU > @c_CurrentSKU
-- Remarked by June 18.Nov.04 : SOS29580         
--       AND StorerKey = @c_CurrentStorer
         ORDER BY SKU
         IF @@ROWCOUNT = 0
         BEGIN
            SET ROWCOUNT 0
            BREAK
         END
         SET ROWCOUNT 0
         -- SOS 2199 for Taiwan
         -- start: 2199
         select @c_hostwhcode = hostwhcode
         from loc (nolock)
         where loc = @c_CurrentLoc
         -- end: 2199
         /* We now have a pickLOCation that needs to be replenished! */
         /* Figure out which LOCations in the warehouse to pull this product from */
         /* End figure out which LOCations in the warehouse to pull this product from */
         SELECT @c_FromLOC = SPACE(10),  @c_fromlot = SPACE(10), @c_fromid = SPACE(18),
         @n_FromQty = 0, @n_possiblecases = 0, 
         @n_Remainingqty = @n_CurrentSeverity, -- Modify by SHONG on 29th Sep 2006 
         -- @n_Remainingqty = @n_CurrentSeverity * @n_currentfullcase,
         @n_remainingcases = CASE WHEN @n_currentfullcase > 0 
                                  THEN @n_CurrentSeverity / @n_currentfullcase
                                  ELSE @n_CurrentSeverity
                             END,
         @c_fromlot2 = SPACE(10),
         @b_DoneCheckOverAllocatedLots = 0

         IF @c_zone02 = 'ALL'
         BEGIN
            DECLARE LOT_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT LOTxLOCxID.LOT
            FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), ID (NOLOCK)
            WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
            AND LOTxLOCxID.SKU = @c_CurrentSKU
            AND LOTxLOCxID.LOC = LOC.LOC
            AND LOC.LocationFlag <> 'DAMAGE'
            AND LOC.LocationFlag <> 'HOLD'
            AND LOC.Status <> 'HOLD'
            AND LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0
            AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
            AND LOTxLOCxID.LOC <> @c_CurrentLoc
            AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
            AND LOC.Facility = @c_zone01
            AND LOC.HostwhCode = @c_Hostwhcode -- sos 2199
            AND LOTxLOCxID.LOT = LOT.Lot       -- Added By YTWan on 07-Oct-2004
            AND LOT.Status     = 'OK'          -- Added By YTWan on 07-Oct-2004
            AND LOTxLOCxID.ID  = ID.ID         -- Added By YTWan on 07-Oct-2004
            AND ID.Status      <> 'HOLD'       -- Added By YTWan on 07-Oct-2004
            GROUP BY LOTxLOCxID.LOT  
            ORDER BY CASE WHEN SUM(LOTxLOCxID.QtyExpected) > 0 THEN 1 ELSE 2 END,
                               MIN(LOTTABLE04), MIN(LOTTABLE05)

         END
         ELSE
         BEGIN
            DECLARE LOT_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT LOTxLOCxID.LOT
            FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), ID (NOLOCK)
            WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
            AND LOTxLOCxID.SKU = @c_CurrentSKU
            AND LOTxLOCxID.LOC = LOC.LOC
            AND LOC.LocationFlag <> 'DAMAGE'
            AND LOC.LocationFlag <> 'HOLD'
            AND LOC.Status <> 'HOLD'
            AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0
            AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demand
            AND LOTxLOCxID.LOC <> @c_CurrentLoc
            AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
            AND LOC.Facility = @c_zone01
            AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
            -- 2006 Oct 02
            -- Comment by SHONG, Shouldn't filter Zone for From Loc.
            -- AND LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
            AND LOTxLOCxID.LOT = LOT.Lot       -- Added By YTWan on 07-Oct-2004
            AND LOT.Status     = 'OK'          -- Added By YTWan on 07-Oct-2004
            AND LOTxLOCxID.ID  = ID.ID         -- Added By YTWan on 07-Oct-2004
            AND ID.Status      <> 'HOLD'       -- Added By YTWan on 07-Oct-2004
            GROUP BY LOTxLOCxID.LOT   
            ORDER BY CASE WHEN SUM(LOTxLOCxID.QtyExpected) > 0 THEN 1 ELSE 2 END,
                               MIN(LOTTABLE04), MIN(LOTTABLE05) 
         END

         OPEN LOT_CUR

         FETCH NEXT FROM LOT_CUR INTO @c_FromLot 
         WHILE @@Fetch_Status <> -1 AND @n_remainingqty > 0 
         BEGIN
            SET ROWCOUNT 0
            SELECT @c_FromLOC = SPACE(10) 

            WHILE (1=1 AND @n_remainingqty > 0) 
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
               AND LOTxLOCxID.qty - QtyPicked - QtyAllocated > 0
               AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
               AND LOTxLOCxID.LOC <> @c_CurrentLoc
               AND LOC.Facility = @c_zone01
               -- AND LOC.LocLevel > 1
               AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
               ORDER BY LOTxLOCxID.LOC

               IF @@ROWCOUNT = 0
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT 'Not Lot Available! SKU= ' + @c_CurrentSKU + ' @c_FromLOC=' + @c_FromLOC + ' From LOT=' + @c_fromlot +
                     ' HostWHCode=' +  @c_hostwhcode
                  END

                  SET ROWCOUNT 0
                  -- BREAK
                  GOTO FIND_NEXT_LOT
               END

               SET ROWCOUNT 0
               SELECT @c_fromid = replicate('Z',18)
               WHILE (1=1 AND @n_remainingqty > 0)
               BEGIN
                  IF @c_zone02 = 'ALL'
                  BEGIN
                     SET ROWCOUNT 1
                     SELECT @c_fromid = ID,
                     @n_OnHandQty = LOTxLOCxID.QTY - QtyPicked - QtyAllocated
                     FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                     WHERE LOT = @c_fromlot
                     AND LOTxLOCxID.LOC = LOC.LOC
                     AND LOTxLOCxID.LOC = @c_FromLOC
                     AND id < @c_fromid
                     AND StorerKey = @c_CurrentStorer
                     AND SKU = @c_CurrentSKU
                     AND  LOC.LocationFlag <> 'DAMAGE'
                     AND  LOC.LocationFlag <> 'HOLD'
                     AND  LOC.Status <> 'HOLD'
                     AND LOTxLOCxID.qty - QtyPicked - QtyAllocated > 0
                     AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                     AND LOTxLOCxID.LOC <> @c_CurrentLoc
                     AND LOC.Facility = @c_zone01
                     AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
                     ORDER BY ID DESC
                  END
                  ELSE
                  BEGIN
                     SET ROWCOUNT 1
                     SELECT @c_fromid = ID,
                            @n_OnHandQty = LOTxLOCxID.QTY - QtyPicked - QtyAllocated
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
                     AND LOTxLOCxID.qty - QtyPicked - QtyAllocated > 0
                     AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                     AND LOTxLOCxID.LOC <> @c_CurrentLoc
                     AND LOC.Facility = @c_zone01
                     AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
                     -- 2006 Oct 02
                     -- Comment by SHONG, Shouldn't filter Zone for From Loc.
                     -- AND LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                     ORDER BY ID DESC
                  END
                  IF @@ROWCOUNT = 0
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Stop because No Pallet Found! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_FromLOC
                        + ' From ID = ' + @c_fromid
                     END
                     SET ROWCOUNT 0
                     GOTO FIND_NEXT_LOT
                  END
                  SET ROWCOUNT 0
                  /* We have a cANDidate FROM record */
                  /* Verify that the cANDidate ID is not on HOLD */
                  /* We could have done this in the SQL statements above */
                  /* But that would have meant a 5-way join.             */
                  /* SQL SERVER seems to work best on a maximum of a     */
                  /* 4-way join.                                         */
                  IF EXISTS(SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_fromid
                  AND STATUS = 'HOLD')
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Stop because ID Status = HOLD! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU + ' ID = ' + @c_fromid
                     END
                     CONTINUE -- Should Try Another ID instead of Terminate
                     -- BREAK -- Get out of loop, so that next cANDidate can be evaluated
                  END
                  /* Verify that the from LOCation is not overalLOCated in SKUxLOC */
                  IF EXISTS(SELECT 1 FROM SKUxLOC (NOLOCK)
                            WHERE StorerKey = @c_CurrentStorer
                            AND SKU = @c_CurrentSKU
                            AND LOC = @c_FromLOC
                            AND QtyExpected > 0
                  )
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Stop because Qty Expected > 0! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU
                     END
                     
                     BREAK -- Get out of loop, so that next cANDidate can be evaluated
                  END
                  /* Verify that the FROM LOCation is not the */
                  /* PIECE PICK LOCation for this product.    */
                  IF EXISTS(SELECT 1 FROM SKUxLOC (NOLOCK)
                  WHERE StorerKey = @c_CurrentStorer
                  AND SKU = @c_CurrentSKU
                  AND LOC = @c_FromLOC
                  AND LOCATIONTYPE = 'PICK'
                  )
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Stop because LOCation Type = PICK! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU
                     END
                     BREAK -- Get out of loop, so that next cANDidate can be evaluated
                  END
                  /* Verify that the FROM LOCation is not the */
                  /* CASE PICK LOCation for this product.     */
                  IF EXISTS(SELECT 1 FROM SKUxLOC (NOLOCK)
                  WHERE StorerKey = @c_CurrentStorer
                  AND SKU = @c_CurrentSKU
                  AND LOC = @c_FromLOC
                  AND LOCATIONTYPE = 'CASE'
                  )
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Stop because LOCation Type = CASE! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU
                     END
                     BREAK -- Get out of loop, so that next cANDidate can be evaluated
                  END

                  DECLARE @cLocationHandling NVARCHAR(10), 
                          @nFullCaseQty      int 

                  SELECT @cLocationHandling = LocationHandling 
                  FROM   LOC (NOLOCK) 
                  WHERE  LOC = @c_CurrentLoc 

                  SET @nFullCaseQty = 0
                  SET @n_FullPallet = 0

                        
                  IF @cLocationHandling <> '2' -- Case Only 
                  BEGIN 
                     /* At this point, get the available qty from */
                     /* the SKUxLOC record.                       */
                     /* If it's less than what was taken from the */
                     /* lotxLOCxid record, then use it.           */
                     SELECT @n_FullPallet = QTY - QtyAllocated - QtyPicked
                     FROM LOTxLOCxID (NOLOCK)
                     WHERE StorerKey = @c_CurrentStorer
                     AND SKU = @c_CurrentSKU
                     AND LOC = @c_FromLOC
                     AND LOT = @c_fromlot
                     AND ID  = @c_fromid

                     SELECT @n_PalletCnt = ISNULL(PACK.Pallet, 0) 
                     FROM   SKU (NOLOCK) 
                     JOIN   PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey 
                     WHERE  SKU.StorerKey = @c_CurrentStorer
                     AND    SKU.SKU = @c_CurrentSKU
                     
                     -- 07-Nov-2006  Shong 
                     -- If LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > Pallet Qty
                     -- Then use Pallet Qty...
                     IF @n_PalletCnt > 0 AND @n_FullPallet > @n_PalletCnt 
                     BEGIN
                        SET @n_FullPallet = FLOOR(@n_FullPallet / @n_PalletCnt) * @n_PalletCnt
                     END 

                  END    
                  ELSE
                  BEGIN
                     /* How many cases can I get from this record? */
                     IF @n_CurrentFullCase > @n_OnHandQty OR @n_CurrentFullCase = 0 
                        SET @nFullCaseQty = @n_OnHandQty 
                     ELSE
                     BEGIN
                        SELECT @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullCase)

                        IF @n_OnHandQty % @n_CurrentFullCase > 0 
                           SET @n_PossibleCases = @n_PossibleCases + 1 

                        SELECT @nFullCaseQty = @n_PossibleCases * @n_CurrentFullCase 

                        IF @nFullCaseQty > @n_OnHandQty 
                           SET @nFullCaseQty = @n_OnHandQty 
                     END 
                  END 


                  /* How many do we take? */
                  IF @cLocationHandling = '2' -- Case Only 
                  BEGIN 
                     IF @n_RemainingQty >= @nFullCaseQty
                     BEGIN
                        SELECT @n_FromQty = @nFullCaseQty,
                               @n_RemainingQty = @n_RemainingQty - @nFullCaseQty
                     END
                     ELSE
                     BEGIN
                        -- Shong 
                        -- Force to replen full case
                        IF @n_CurrentFullCase > 0 AND @n_CurrentFullCase > @nFullCaseQty 
                        BEGIN 
                           -- get full case qty 
                           SELECT @n_PossibleCases = FLOOR(@n_RemainingQty / @n_CurrentFullCase)
                           
                           -- trade remaining qty as 1 full case
                           IF @n_RemainingQty % @n_CurrentFullCase > 0 
                              SET @n_PossibleCases = @n_PossibleCases + 1

                           SELECT @nFullCaseQty = @n_PossibleCases * @n_CurrentFullCase 

                           IF @nFullCaseQty > @n_RemainingQty  
                              SET @nFullCaseQty = @n_RemainingQty  
                        END 
                        ELSE 
                           SELECT @nFullCaseQty = @n_RemainingQty

                        SELECT @n_FromQty = @nFullCaseQty,
                               @n_RemainingQty = @n_RemainingQty - @nFullCaseQty
                     END
                  END    
                  ELSE
                  BEGIN
                     IF @n_RemainingQty >= @n_FullPallet
                     BEGIN
                        SELECT @n_FromQty = @n_FullPallet,
                               @n_RemainingQty = @n_RemainingQty - @n_FullPallet
                     END
                     ELSE
                     BEGIN
                        -- Shong 
                        -- Force to replen full pallet
                        SELECT @n_FromQty = 0
                     END
                  END 

                  IF @b_debug = 1
                  BEGIN
                     SELECT @n_CurrentSeverity '@n_CurrentSeverity', @n_FullPallet '@n_FullPallet', 
                            @nFullCaseQty '@nFullCaseQty', @n_OnHandQty '@n_OnHandQty', @n_CurrentFullCase '@n_CurrentFullCase', 
                            @n_RemainingQty '@n_RemainingQty', @cLocationHandling '@cLocationHandling'
                  END


                  IF @n_FromQty > 0
                  BEGIN
                     SELECT @c_Packkey = PACK.PackKey,
                            @c_UOM = PACK.PackUOM3
                     FROM   SKU (NOLOCK), PACK (NOLOCK)
                     WHERE  SKU.PackKey = PACK.Packkey
                     AND    SKU.StorerKey = @c_CurrentStorer
                     AND    SKU.SKU = @c_CurrentSKU

                     IF @n_continue = 1 or @n_continue = 2
                     BEGIN
                        IF NOT EXISTS(SELECT 1 FROM #REPLENISHMENT WHERE LOT =  @c_fromlot AND
                                       FromLOC = @c_FromLOC AND ID = @c_fromid)
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
                           @c_CurrentSKU,
                           @c_FromLOC,
                           @c_CurrentLoc,
                           @c_fromlot,
                           @c_fromid,
                           @n_FromQty,
                           @c_UOM,
                           @c_Packkey,
                           @c_CurrentPriority,
                           0,0)
                        END 
                     END
                     SELECT @n_numberofrecs = @n_numberofrecs + 1

                     IF @b_debug = 1
                     BEGIN
                        SELECT 'INSERTED : ' as Title, @c_CurrentSKU ' SKU', @c_fromlot 'LOT',  @c_CurrentLoc 'LOC', @c_fromid 'ID', 
                               @n_FromQty 'Qty'
                     END 
                              
                  END -- if from qty > 0
                  IF @b_debug = 1
                  BEGIN
                     select @c_CurrentSKU ' SKU', @c_CurrentLoc 'LOC', @c_CurrentPriority 'priority', @n_currentfullcase 'full case', @n_CurrentSeverity 'severity'
                     -- select @n_FromQty 'qty', @c_FromLOC 'fromLOC', @c_fromlot 'from lot', @n_possiblecases 'possible cases'
                     select @n_RemainingQty '@n_RemainingQty', @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU, @c_fromlot 'from lot', @c_fromid
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

            FIND_NEXT_LOT:
            FETCH NEXT FROM LOT_CUR INTO @c_FromLot
         END -- LOT 
         CLOSE LOT_CUR 
         DEALLOCATE LOT_CUR 
      END -- -- FOR SKU
   END 
   SET ROWCOUNT 0
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      /* Update the column QtyInPickLOC in the Replenishment Table */
      IF @n_continue = 1 or @n_continue = 2
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
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM
   FROM #REPLENISHMENT R
   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
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
         VALUES ('IDS',
         @c_ReplenishmentKey,
         @c_CurrentStorer,
         @c_CurrentSKU,
         @c_FromLOC,
         @c_CurrentLoc,
         @c_FromLot,
         @c_FromId,
         @n_FromQty,
         @c_UOM,
         @c_PackKey,
         'N')
         SELECT @n_err = @@ERROR

      END -- IF @b_success = 1
      FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
   END -- While
   CLOSE CUR1 
   DEALLOCATE CUR1
   -- End Insert Replenishment

   --(Wan01) - START
   QUIT_SP:
   IF @c_Functype = 'G'
   BEGIN
      RETURN
   END
   --(Wan01) - END

   IF ( @c_zone02 = 'ALL')
   BEGIN
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey,
      LA.Lottable04, LA.Lottable02
      FROM  REPLENISHMENT R (NOLOCK) 
      JOIN  SKU (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
      JOIN  LOC (NOLOCK) ON (LOC.Loc = R.FromLoc)
      JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      JOIN  Lotattribute LA (NOLOCK) ON (LA.Sku = R.Sku AND  LA.StorerKey = R.StorerKey
                                         AND  LA.Lot = R.Lot  )
      WHERE LOC.facility = @c_zone01
      AND   R.confirmed = 'N' 
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')          --(Wan01)  
      AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')     --(Wan01)  
      ORDER BY LOC.PutawayZone, R.Priority
   END
   ELSE
   BEGIN
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, 
      LA.Lottable04, LA.Lottable02 
      FROM  REPLENISHMENT R (NOLOCK), SKU (NOLOCK), LOC (NOLOCK), PACK (NOLOCK) -- Pack table added by Jacob. Date: Jan 03, 2001
            , Lotattribute LA (NOLOCK) 
      WHERE SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
      AND LOC.Loc = R.ToLoc
      AND SKU.PackKey = PACK.PackKey
      AND LOC.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
      and loc.facility = @c_zone01
      AND confirmed = 'N'
      AND LA.Sku = R.Sku 
      AND LA.StorerKey = R.StorerKey
      AND LA.Lot = R.Lot 
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')          --(Wan01)  
      AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')     --(Wan01)  
      ORDER BY LOC.PutawayZone, R.Priority
   END
END

GO