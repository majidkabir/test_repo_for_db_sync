SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_ReplenishmentRpt_PC03                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 13-Dec-2002  Wally      SOS 8935 - UOM in Replenishment              */
/* 16-Dec-2004  Shong      Change cursor type                           */
/* 20-Jul-2005  Loon       Add drop object                              */
/* 18-Nov-2005  MaryVong   -> SOS43179 Bug Fixed                        */
/*                         -> Enhance script by using cursor loop to get*/
/*                            available lot, loc, id and onhandqty for  */
/*                            replenishment where:                      */
/*                            1) with qty overallocated (qtyexpected >0)*/
/*                               with higher priority                   */
/*                            2) in FEFO sequence                       */
/*                            3) Group Lot, Loc, ID and OnHandQty into  */
/*                               one cursor, ie. Cur_LOTxLOCxIDxQty     */
/* 18-JAN-2019  Wan01    1.7   WM - Add Storerkey, ReplCgrp & Functype  */
/************************************************************************/

CREATE PROC    [dbo].[nsp_ReplenishmentRpt_PC03]
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

   DECLARE  @n_continue int   /* continuation flag 
                              1=Continue
                              2=failed but continue processsing 
                              3=failed do not continue processing 
                              4=successful but skip furthur processing */
   DECLARE @b_debug int,
   @c_Packkey NVARCHAR(10),
   @c_UOM     NVARCHAR(10)  -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)

   SELECT @n_continue=1,
   @b_debug = 0

   IF @c_zone12 <> ''
      SELECT @b_debug = CAST( @c_zone12 AS int)

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

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_CurrentSKU NVARCHAR(20), @c_CurrentStorer NVARCHAR(15),
      @c_CurrentLOC NVARCHAR(10), @c_CurrentPriority NVARCHAR(5),
      @n_CurrentFullcase int, @n_CurrentSeverity int,
      @c_FromLoc NVARCHAR(10), @c_FromLot NVARCHAR(10), @c_FromId NVARCHAR(18),
      @n_FromQty int, @n_RemainingQty int, @n_PossibleCases int ,
      @n_RemainingCases int, @n_OnHandQty int, @n_FromCases int ,
      @c_ReplenishmentKey NVARCHAR(10), @n_NumberOfRecs int, @n_LimitRecs int,
--       @c_FromLot2 NVARCHAR(10),
--       @b_DoneCheckOverAllocatedLots int,
      @n_SKULOCavailableqty int,
      @c_hostwhcode NVARCHAR(10) -- sos 2199
      SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
      @c_CurrentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),
      @n_CurrentFullcase = 0 , @n_CurrentSeverity = 9999999 ,
      @n_FromQty = 0, @n_RemainingQty = 0, @n_PossibleCases = 0,
      @n_RemainingCases =0, @n_FromCases = 0, @n_NumberOfRecs = 0,
      @n_LimitRecs = 5
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
         WHERE  (SKUxLOC.LOCationtype = "PICK" OR SKUxLOC.LOCationtype = "CASE")
         AND  ReplenishmentSeverity > 0
         AND  SKUxLOC.LOC = LOC.LOC
         AND  LOC.FACILITY = @c_Zone01
         AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)  
      END
      ELSE
      BEGIN
         INSERT #TempSKUxLOC
         SELECT ReplenishmentPriority, ReplenishmentSeverity ,StorerKey,
         SKU, LOC.LOC, ReplenishmentCasecnt
         FROM SKUxLOC (NOLOCK), LOC (NOLOCK)
         WHERE SKUxLOC.LOC = LOC.LOC
         AND  LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         AND  LOC.LOCationflag <> "DAMAGE"
         AND  LOC.LOCationflag <> "HOLD"
         AND  (SKUxLOC.LOCationtype = "PICK" OR SKUxLOC.LOCationtype = "CASE")
         AND  ReplenishmentSeverity > 0
         AND  SKUxLOC.qty - SKUxLOC.qtypicked - SKUxLOC.QtyPickInProcess < SKUxLOC.QtyLOCationMinimum
         AND  LOC.FACILITY = @c_Zone01
         AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01) 
      END
      WHILE (1=1)
      BEGIN
         IF @c_zone02 = "ALL"
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_CurrentPriority = ReplenishmentPriority
            FROM #TempSKUxLOC
            WHERE ReplenishmentPriority > @c_CurrentPriority
            AND  ReplenishmentCasecnt > 0
            ORDER BY ReplenishmentPriority
         END
         ELSE
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_CurrentPriority = ReplenishmentPriority
            FROM #TempSKUxLOC
            WHERE ReplenishmentPriority > @c_CurrentPriority
            AND  ReplenishmentCasecnt > 0
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
            SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
            @c_CurrentLOC = SPACE(10)
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1
               SELECT @c_CurrentStorer = StorerKey
               FROM #TempSKUxLOC
               WHERE StorerKey > @c_CurrentStorer
               AND ReplenishmentSeverity = @n_CurrentSeverity
               AND ReplenishmentPriority = @c_CurrentPriority
               ORDER BY StorerKey
               IF @@ROWCOUNT = 0
               BEGIN
                  SET ROWCOUNT 0
                  BREAK
               END
               SET ROWCOUNT 0
               /* Now - for this priority, this severity - find the next SKU row */
               /* that matches */
               SELECT @c_CurrentSKU = SPACE(20),
               @c_CurrentLOC = SPACE(10)
               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_CurrentStorer = StorerKey ,
                  @c_CurrentSKU = SKU,
                  @c_CurrentLOC = LOC,
                  @n_CurrentFullcase = ReplenishmentCasecnt
                  FROM #TempSKUxLOC
                  WHERE SKU > @c_CurrentSKU
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
                  -- SOS 2199 for Taiwan
                  -- start: 2199
                  SELECT @c_hostwhcode = hostwhcode
                  FROM LOC (NOLOCK)
                  WHERE Loc = @c_CurrentLOC
                  -- end: 2199
                  /* We now have a pickLOCation that needs to be replenished! */
                  /* Figure out which LOCations in the warehouse to pull this product from */
                  /* End figure out which LOCations in the warehouse to pull this product from */
                  SELECT @c_FromLoc = SPACE(10),  @c_FromLot = SPACE(10), @c_FromId = SPACE(18),
                  @n_FromQty = 0, @n_PossibleCases = 0,
                  @n_RemainingQty = @n_CurrentSeverity * @n_CurrentFullcase,
                  @n_RemainingCases = @n_CurrentSeverity

                  -- SOS43179 EndModified by MaryVong on 18-Nov-2005 -- Start
                  -- Combine coding to get Lot, Loc, Id and OnHandQty where lot which have 
                  -- OverAllocated Qty (QtyExpected > 0) and normal lot
                  -- Set lots which have Qty overallocated as higher priority
                  DECLARE Cur_LOTxLOCxIDxQty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID,
                        LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated
                  FROM  LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK),
                        LOT (NOLOCK), ID (NOLOCK)
                  WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
                  AND   LOTxLOCxID.SKU = @c_CurrentSKU
                  AND   LOTxLOCxID.LOC = LOC.LOC
                  AND   LOC.LOCationflag <> "DAMAGE"
                  AND   LOC.LOCationflag <> "HOLD"
                  AND   ( (LOTxLOCxID.QtyExpected > 0 AND LOTxLOCxID.LOC = @c_CurrentLOC) OR 
                          (LOTxLOCxID.QtyExpected = 0 AND LOTxLOCxID.LOC <> @c_CurrentLOC AND 
                              (LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated) > 0) 
                        )                 
                  AND   LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                  AND   LOTxLOCxID.LOT = LOT.LOT
                  AND   LOT.Status = 'OK'
                  AND   LOTxLOCxID.ID = ID.ID
                  AND   ID.Status = 'OK'
                  AND   LOC.Facility = @c_Zone01
                  AND   LOC.hostwhcode = @c_hostwhcode -- sos 2199
                  ORDER BY CASE WHEN LOTxLOCxID.QtyExpected > 0 THEN 1 ELSE 2 END, 
                           LOTTABLE04, LOTTABLE05

                  OPEN Cur_LOTxLOCxIDxQty 


--                   WHILE (1=1)
--                   BEGIN
--                      /* See if there are any lots where the QTY is overalLOCated... */
--                      /* if Yes then uses this lot first... */
--                      -- That means that the last try at this section of code was successful therefore try again.
--                      IF @b_DoneCheckOverAllocatedLots = 0
--                      BEGIN
--                         IF @c_zone02 = "ALL"
--                         BEGIN
--                            SET ROWCOUNT 1
--                            SELECT @c_FromLot2 = LOTxLOCxID.LOT
--                            FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
--                            WHERE LOTxLOCxID.LOT > @c_FromLot2
--                            AND LOTxLOCxID.StorerKey = @c_CurrentStorer
--                            AND LOTxLOCxID.SKU = @c_CurrentSKU
--                            AND LOTxLOCxID.LOC = LOC.LOC
--                            AND LOC.LOCationflag <> "DAMAGE"
--                            AND LOC.LOCationflag <> "HOLD"
--                            AND LOTxLOCxID.qtyexpected > 0
--                            AND LOTxLOCxID.LOC = @c_CurrentLOC
--                            AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
--                            AND LOC.Facility = @c_zone01
--                            AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
--                            ORDER BY LOTTABLE04, LOTTABLE05
--                         END
--                      ELSE
--                         BEGIN
--                            SET ROWCOUNT 1
--                            SELECT @c_FromLot2 = LOTxLOCxID.LOT
--                            FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
--                            WHERE LOTxLOCxID.LOT > @c_FromLot2
--                            AND LOTxLOCxID.StorerKey = @c_CurrentStorer
--                            AND LOTxLOCxID.SKU = @c_CurrentSKU
--                            AND LOTxLOCxID.LOC = LOC.LOC
--                            AND LOTxLOCxID.qtyexpected > 0
--                            AND LOTxLOCxID.LOC = @c_CurrentLOC
--                            AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
--                            AND LOC.Facility = @c_zone01
--                            AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
--                            AND LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
--                            ORDER BY LOTTABLE04, LOTTABLE05
--                         END
--                         IF @@ROWCOUNT = 0
--                         BEGIN
--                            SELECT @b_DoneCheckOverAllocatedLots = 1
--                            SELECT @c_FromLot = ""
--                         END
--                      ELSE
--                         SELECT @b_DoneCheckOverAllocatedLots = 1
--                      END --IF @b_DoneCheckOverAllocatedLots = 0
--                      /* End see if there are any lots where the QTY is overalLOCated... */
--                      SET ROWCOUNT 0
--                      /* If there are not lots overalLOCated in the candidate location, simply pull lots into the LOCation by lot # */
--                      IF @b_DoneCheckOverAllocatedLots = 1
--                      BEGIN
--                         /* Select any lot if no lot was over alLOCated */
--                         IF @c_zone02 = "ALL"
--                         BEGIN
--                            SET ROWCOUNT 1
--                            SELECT @c_FromLot = LOTxLOCxID.LOT
--                            FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
--                            WHERE LOTxLOCxID.LOT > @c_FromLot
--                            AND LOTxLOCxID.StorerKey = @c_CurrentStorer
--                            AND LOTxLOCxID.SKU = @c_CurrentSKU
--                            AND LOTxLOCxID.LOC = LOC.LOC
--                            AND LOC.LOCationflag <> "DAMAGE"
--                            AND LOC.LOCationflag <> "HOLD"
--                            AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
--                            AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
--                            AND LOTxLOCxID.LOC <> @c_CurrentLOC
--                            AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
--                            AND LOC.Facility = @c_zone01
--                            AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
--                            ORDER BY LOTTABLE04, LOTTABLE05
--                         END
--                      ELSE
--                         BEGIN
--                            SET ROWCOUNT 1
--                            SELECT @c_FromLot = LOTxLOCxID.LOT
--                            FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
--                            WHERE LOTxLOCxID.LOT > @c_FromLot
--                            AND LOTxLOCxID.StorerKey = @c_CurrentStorer
--                            AND LOTxLOCxID.SKU = @c_CurrentSKU
--                            AND LOTxLOCxID.LOC = LOC.LOC
--                            AND LOC.LOCationflag <> "DAMAGE"
--                            AND LOC.LOCationflag <> "HOLD"
--                            AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
--                            AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demand
--                            AND LOTxLOCxID.LOC <> @c_CurrentLOC
--                            AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
--                            AND LOC.Facility = @c_zone01
--                            AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
--                            AND LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
--                            ORDER BY LOTTABLE04, LOTTABLE05
--                         END
--                         IF @@ROWCOUNT = 0
--                         BEGIN
--                            IF @b_debug = 1
--                            SELECT 'Not Lot Available! SKU= ' + @c_CurrentSKU + ' LOC=' + @c_CurrentLOC
--                            SET ROWCOUNT 0
--                            BREAK
--                         END
--                         SET ROWCOUNT 0
--                      END
--                   ELSE
--                      BEGIN
--                         SELECT @c_FromLot = @c_FromLot2
--                      END -- IF @b_DoneCheckOverAllocatedLots = 1
--                      SET ROWCOUNT 0

                  FETCH NEXT FROM Cur_LOTxLOCxIDxQty INTO @c_FromLot, @c_FromLoc, @c_FromId, @n_OnHandQty
   
                  IF @@FETCH_STATUS = -1 
                  BEGIN
                     IF @b_debug = 1
                     SELECT 'Not Lot Available! SKU= ' + @c_CurrentSKU + ' LOC=' + @c_CurrentLOC + ' LOT=' + @c_FromLot 
                  END

                  WHILE @@FETCH_STATUS <> -1 
                  BEGIN
                     IF @b_debug = 1
                     SELECT 'Lot Found! SKU= ' + @c_CurrentSKU + ' LOC=' + @c_CurrentLOC + ' LOT=' + @c_FromLot 

                     IF (@n_RemainingQty > 0)
                     BEGIN

--                      SELECT @c_FromLoc = SPACE(10)
--                      WHILE (1=1 AND @n_RemainingQty > 0)
--                      BEGIN
--                         IF @c_zone02 = "ALL"
--                         BEGIN
--                            SET ROWCOUNT 1
--                            SELECT @c_FromLoc = LOTxLOCxID.LOC
--                            FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
--                            WHERE LOT = @c_FromLot
--                            AND LOTxLOCxID.LOC = LOC.LOC
--                            AND LOTxLOCxID.LOC > @c_FromLoc
--                            AND StorerKey = @c_CurrentStorer
--                            AND SKU = @c_CurrentSKU
--                            AND LOTxLOCxID.LOC = LOC.LOC
--                            AND LOC.LOCationflag <> "DAMAGE"
--                            AND LOC.LOCationflag <> "HOLD"
--                            AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
--                            AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
--                            AND LOTxLOCxID.LOC <> @c_CurrentLOC
--                            AND LOC.Facility = @c_zone01
--                            AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
--                            ORDER BY LOTxLOCxID.LOC
--                         END
--                         ELSE
--                         BEGIN
--                            SET ROWCOUNT 1
--                            SELECT @c_FromLoc = LOTxLOCxID.LOC
--                            FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
--                            WHERE LOT = @c_FromLot
--                            AND LOTxLOCxID.LOC = LOC.LOC
--                            AND LOTxLOCxID.LOC > @c_FromLoc
--                            AND StorerKey = @c_CurrentStorer
--                            AND SKU = @c_CurrentSKU
--                            AND LOTxLOCxID.LOC = LOC.LOC
--                            AND LOC.LOCationflag <> "DAMAGE"
--                            AND LOC.LOCationflag <> "HOLD"
--                            AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
--                            AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
--                            AND LOTxLOCxID.LOC <> @c_CurrentLOC
--                            AND LOC.Facility = @c_zone01
--                            AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
--                            AND LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
--                            ORDER BY LOTxLOCxID.LOC
--                         END
--                         IF @@ROWCOUNT = 0
--                         BEGIN
--                            SET ROWCOUNT 0
--                            BREAK
--                         END
--                         SET ROWCOUNT 0

--if @b_debug = 1
-- select 'out from id loop'
                        
--                         SELECT @c_FromId = replicate('Z',18)
--                         WHILE (1=1 AND @n_RemainingQty > 0)
--                         BEGIN
--                            IF @c_zone02 = "ALL"
--                            BEGIN
--                               SET ROWCOUNT 1
--                               SELECT @c_FromId = ID,
--                               @n_OnHandQty = LOTxLOCxID.QTY - QTYPICKED - QTYALLOCATED
--                               FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
--                               WHERE LOT = @c_FromLot
--                               AND LOTxLOCxID.LOC = LOC.LOC
--                               AND LOTxLOCxID.LOC = @c_FromLoc
--                               AND id < @c_FromId
--                               AND StorerKey = @c_CurrentStorer
--                               AND SKU = @c_CurrentSKU
--                               AND  LOC.LOCationflag <> "DAMAGE"
--                               AND  LOC.LOCationflag <> "HOLD"
--                               AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
--                               AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
--                               AND LOTxLOCxID.LOC <> @c_CurrentLOC
--                               AND LOC.Facility = @c_zone01
--                               AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
--                               ORDER BY ID DESC
--                            END
--                            ELSE
--                            BEGIN
--                               SET ROWCOUNT 1
--                               SELECT @c_FromId = ID,
--                               @n_OnHandQty = LOTxLOCxID.QTY - QTYPICKED - QTYALLOCATED
--                               FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
--                               WHERE LOT = @c_FromLot
--                               AND LOTxLOCxID.LOC = LOC.LOC
--                               AND LOTxLOCxID.LOC = @c_FromLoc
--                               AND id < @c_FromId
--                               AND StorerKey = @c_CurrentStorer
--                               AND SKU = @c_CurrentSKU
--                               AND LOC.LOCationflag <> "DAMAGE"
--                               AND LOC.LOCationflag <> "HOLD"
--                               AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
--                               AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
--                               AND LOTxLOCxID.LOC <> @c_CurrentLOC
--                               AND LOC.Facility = @c_zone01
--                               AND LOC.hostwhcode = @c_hostwhcode -- sos 2199
--                               AND LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
--                               ORDER BY ID DESC
--                            END
--                            IF @@ROWCOUNT = 0
--                            BEGIN
--                               IF @b_debug = 1
--                               BEGIN
--                                  SELECT 'Stop because No Pallet Found! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU + ' LOT = ' + @c_FromLot + ' From LOC = ' + @c_FromLoc
--                                  + ' From ID = ' + @c_FromId
--                               END
--                               SET ROWCOUNT 0
--                               BREAK
--                            END
--                            SET ROWCOUNT 0

                     
                           /* We have a candidate from record */
                           /* Verify that the candidate ID is not on HOLD */
                           /* We could have done this in the SQL statements above */
                           /* But that would have meant a 5-way join.             */
                           /* SQL SERVER seems to work best on a maximum of a     */
                           /* 4-way join.                                         */
--                            IF EXISTS(SELECT * FROM ID (NOLOCK) WHERE ID = @c_FromId
--                            AND STATUS = "HOLD")
--                            BEGIN
--                               IF @b_debug = 1
--                               BEGIN
--                                  SELECT 'Stop because Location Status = HOLD! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU + ' ID = ' + @c_FromId
--                               END
--                               BREAK -- Get out of loop, so that next candidate can be evaluated
--                            END
                        /* Verify that the from location is not overallocated in SKUxLOC */
                        IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                        WHERE StorerKey = @c_CurrentStorer
                        AND SKU = @c_CurrentSKU
                        AND LOC = @c_FromLoc
                        AND QTYEXPECTED > 0
                        )
                        BEGIN
                           IF @b_debug = 1
                           BEGIN
                              SELECT 'Stop because Qty Expected > 0! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
                           END
                           BREAK -- Get out of loop, so that next candidate can be evaluated
                        END
                        /* Verify that the FROM Location is not the */
                        /* PIECE PICK Location for this product.    */
                        IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                        WHERE StorerKey = @c_CurrentStorer
                        AND SKU = @c_CurrentSKU
                        AND LOC = @c_FromLoc
                        AND LOCATIONTYPE = "PICK"
                        )
                        BEGIN
                           IF @b_debug = 1
                           BEGIN
                              SELECT 'Stop because Location Type = PICK! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
                           END
                           BREAK -- Get out of loop, so that next candidate can be evaluated
                        END
                        /* Verify that the FROM Location is not the */
                        /* CASE PICK Location for this product.     */
                        IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                        WHERE StorerKey = @c_CurrentStorer
                        AND SKU = @c_CurrentSKU
                        AND LOC = @c_FromLoc
                        AND LOCATIONTYPE = "CASE"
                        )
                        BEGIN
                           IF @b_debug = 1
                           BEGIN
                              SELECT 'Stop because LOCation Type = CASE! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
                           END
                           BREAK -- Get out of loop, so that next candidate can be evaluated
                        END
                        /* At this point, get the available qty from */
                        /* the SKUxLOC record.                       */
                        /* If it's less than what was taken from the */
                        /* lotxLOCxid record, then use it.           */
                        SELECT @n_SKULOCAvailableQty = QTY - QTYALLOCATED - QTYPICKED
                        FROM SKUxLOC (NOLOCK)
                        WHERE StorerKey = @c_CurrentStorer
                        AND SKU = @c_CurrentSKU
                        AND LOC = @c_FromLoc
                        IF @n_SKULOCavailableqty < @n_OnHandQty
                        BEGIN
                           SELECT @n_OnHandQty = @n_SKULOCAvailableQty
                        END
                        /* How many cases can I get from this record? */
                        SELECT @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullcase)
                        /* How many do we take? */
                        IF @n_OnHandQty > @n_RemainingQty
                        BEGIN
                           SELECT @n_FromQty = @n_RemainingQty,
                           -- @n_RemainingQty = @n_RemainingQty - (@n_RemainingCases * @n_CurrentFullcase),
                           @n_RemainingQty = 0
                        END
                        ELSE
                        BEGIN
                           SELECT @n_FromQty = @n_OnHandQty,
                           @n_RemainingQty = @n_RemainingQty - @n_OnHandQty
                           -- @n_RemainingCases =  @n_RemainingCases - @n_PossibleCases
                        END
                        IF @n_FromQty > 0
                        BEGIN
                           SELECT @c_Packkey = PACK.PackKey,
                           @c_UOM = PACK.PackUOM3
                           FROM   SKU (NOLOCK), PACK (NOLOCK)
                           WHERE  SKU.PackKey = PACK.Packkey
                           AND    SKU.StorerKey = @c_CurrentStorer
                           AND    SKU.SKU = @c_CurrentSKU
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
                              Priority,
                              QtyMoved,
                              QtyInPickLOC)
                              VALUES (
                              @c_CurrentStorer,
                              @c_CurrentSKU,
                              @c_FromLoc,
                              @c_CurrentLOC,
                              @c_FromLot,
                              @c_FromId,
                              @n_FromQty,
                              @c_UOM,
                              @c_Packkey,
                              @c_CurrentPriority,
                              0,0)
                           END
                           SELECT @n_NumberOfRecs = @n_NumberOfRecs + 1
                        END -- if from qty > 0
                        IF @b_debug = 1
                        BEGIN
                           SELECT 'After Insert Replenment:'
                           SELECT @c_CurrentSKU ' SKU', @c_CurrentLOC 'LOC', @c_CurrentPriority 'priority', @n_CurrentFullcase '@n_CurrentFullcase', @n_CurrentSeverity '@n_CurrentSeverity',
                                  @n_RemainingQty '@n_RemainingQty', @c_FromLot '@c_FromLot', @c_FromLoc '@c_FromLoc', @c_FromId '@c_FromId'
                        END
                     END -- IF (@n_RemainingQty > 0)

--                            IF @c_FromId = '' OR @c_FromId IS NULL OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromId)) = ''
--                            BEGIN
--                               -- SELECT @n_RemainingQty=0
--                               BREAK
--                            END
--                         END -- SCAN LOT for ID
--                         SET ROWCOUNT 0
--                      END -- SCAN LOT for LOC

                     SET ROWCOUNT 0
                     FETCH NEXT FROM Cur_LOTxLOCxIDxQty INTO @c_FromLot, @c_FromLoc, @c_FromId, @n_OnHandQty
                  END -- WHILE @@FETCH_STATUS <> -1
                  CLOSE Cur_LOTxLOCxIDxQty
                  DEALLOCATE Cur_LOTxLOCxIDxQty
                  -- SOS43179 -- End
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
   DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM
   FROM #REPLENISHMENT R
   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromId, @c_CurrentLOC, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
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
         @c_CurrentSKU,
         @c_FromLoc,
         @c_CurrentLOC,
         @c_FromLot,
         @c_FromId,
         @n_FromQty,
         @c_UOM,
         @c_PackKey,
         "N")
         SELECT @n_err = @@ERROR

      END -- IF @b_success = 1
      FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromId, @c_CurrentLOC, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
   END -- While
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
      SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey
      FROM  REPLENISHMENT R (NOLOCK), SKU (NOLOCK), LOC (NOLOCK), PACK (NOLOCK) -- Pack table added by Jacob Date Jan 03, 2001
      WHERE SKU.Sku = R.Sku
      AND   SKU.StorerKey = R.StorerKey
      AND   LOC.Loc = R.ToLoc
      AND   SKU.PackKey = PACK.PackKey
      AND   R.Confirmed = 'N'      
      AND   LOC.facility = @c_zone01
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')          --(Wan01)  
      AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')     --(Wan01)  
      ORDER BY LOC.PutawayZone, R.Priority
   END
   ELSE
   BEGIN
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey
      FROM  REPLENISHMENT R (NOLOCK), SKU (NOLOCK), LOC (NOLOCK), PACK (NOLOCK) -- Pack table added by Jacob. Date: Jan 03, 2001
      WHERE SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
      AND   LOC.Loc = R.ToLoc
      AND   SKU.PackKey = PACK.PackKey
      AND   R.Confirmed = 'N'      
      AND   LOC.putawayzone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
      AND   LOC.facility = @c_zone01
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')          --(Wan01)  
      AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')     --(Wan01)  
      ORDER BY LOC.PutawayZone, R.Priority
   END
END

GO