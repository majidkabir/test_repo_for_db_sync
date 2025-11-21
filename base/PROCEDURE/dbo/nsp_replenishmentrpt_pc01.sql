SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_ReplenishmentRpt_PC01                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 05-MAR-2018  Wan01     1.1   WM - Add Functype                       */
/* 05-OCT-2018  CZTENG01  1.2   WM - Add StorerKey, ReplGrp             */
/************************************************************************/

CREATE PROC    [dbo].[nsp_ReplenishmentRpt_PC01]
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
,              @c_storerkey   NVARCHAR(15) = 'ALL' --(CZTENG01)
,              @c_ReplGrp     NVARCHAR(30) = 'ALL' --(CZTENG01)
,              @c_Functype    NCHAR(1) = ''        --(Wan01) 
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
   SELECT @n_starttcnt=@@TRANCOUNT
   DECLARE @b_debug int,
   @c_Packkey NVARCHAR(10),
   @c_UOM     NVARCHAR(10)  -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
   SELECT @n_continue=1,
   @b_debug = 0
   IF @c_zone12 <> ''
   SELECT @b_debug = CAST( @c_zone12 AS int)
   DECLARE @c_priority  NVARCHAR(5)

   --(Wan01) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END

   IF @c_FuncType IN ( 'P' )                                         
   BEGIN                                                             
      GOTO QUIT_SP
   END 
   --(Wan01) - END

   SELECT StorerKey, SKU, LOC FromLOC, LOC ToLOC, Lot, Id, Qty, Qty QtyMoved, Qty QtyInPickLOC,
   @c_priority Priority,
   Lot UOM,
   Lot PackKey
   INTO #REPLENISHMENT
   FROM LOTXLOCXID (NOLOCK)
   WHERE 1 = 2
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_currentSKU NVARCHAR(20), @c_CurrentStorer NVARCHAR(15),
      @c_currentLOC NVARCHAR(10), @c_CurrentPriority NVARCHAR(5),
      @n_CurrentFullCase int, @n_CurrentSeverity int,
      @c_fromLOC NVARCHAR(10), @c_fromlot NVARCHAR(10), @c_fromid NVARCHAR(18),
      @n_FromQty int, @n_remainingqty int, @n_PossibleCases int ,
      @n_remainingcases int, @n_OnHandQty int, @n_fromcases int ,
      @c_ReplenishmentKey NVARCHAR(10), @n_numberofrecs int, @n_limitrecs int,
      @c_fromlot2 NVARCHAR(10),
      @b_DoneCheckOverAllocatedLots int,
      @n_SKULocAvailableQty int
      SELECT @c_currentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
      @c_currentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),
      @n_CurrentFullCase = 0   , @n_CurrentSeverity = 9999999 ,
      @n_FromQty = 0, @n_remainingqty = 0, @n_PossibleCases = 0,
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
         AND  LOC.LocationFlag NOT IN ("DAMAGE", "HOLD")
         AND  (SKUxLOC.LocationType = "PICK" or SKUxLOC.LocationType = "CASE")
         AND  ReplenishmentSeverity > 0
         AND  SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum -- by WALLY
         AND  LOC.FACILITY = @c_Zone01
         AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') --(Wan01)
      END
      ELSE
      BEGIN
         INSERT #TempSKUxLOC
         SELECT ReplenishmentPriority, ReplenishmentSeverity ,StorerKey,
         SKU, LOC.LOC, ReplenishmentCasecnt
         FROM SKUxLOC (NOLOCK), LOC (NOLOCK)
         WHERE SKUxLOC.LOC = LOC.LOC
         AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         AND  LOC.LocationFlag NOT IN ("DAMAGE", "HOLD")
         AND  (SKUxLOC.LocationType = "PICK" or SKUxLOC.LocationType = "CASE")
         AND  ReplenishmentSeverity > 0
         AND  SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum -- by WALLY
         AND  LOC.FACILITY = @c_Zone01
         AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') --(Wan01)
      END
      BEGIN TRANSACTION
         WHILE (1=1)
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_CurrentPriority = ReplenishmentPriority
            FROM #TempSKUxLOC
            WHERE ReplenishmentPriority > @c_CurrentPriority
            AND  ReplenishmentCasecnt > 0
            ORDER BY ReplenishmentPriority
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
               SELECT @c_currentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
               @c_currentLOC = SPACE(10)
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
                  SELECT @c_currentSKU = SPACE(20),
                  @c_currentLOC = SPACE(10)
                  WHILE (1=1)
                  BEGIN
                     SET ROWCOUNT 1
                     SELECT @c_CurrentStorer = StorerKey ,
                     @c_currentSKU = SKU,
                     @c_currentLOC = LOC,
                     @n_CurrentFullCase = ReplenishmentCasecnt
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

                     /* We now have a pickLOCation that needs to be replenished! */
                     /* Figure out which LOCations in the warehouse to pull this product from */
                     /* End figure out which LOCations in the warehouse to pull this product from */

                     SELECT @c_fromLOC = SPACE(10),  @c_fromlot = SPACE(10), @c_fromid = SPACE(18),
                     @n_FromQty = 0, @n_PossibleCases = 0,
                     @n_remainingqty = @n_CurrentSeverity * @n_CurrentFullCase,
                     @n_remainingcases = @n_CurrentSeverity,
                     @c_fromlot2 = SPACE(10),
                     @b_DoneCheckOverAllocatedLots = 0
                     /* suggest replenishment qty less than onhand and picked qty */
                     -- Ammended by SHONG to include remainqty < 0
                     -- WALLY (start)
                     IF @n_remainingqty < 0
                     BEGIN
                        SELECT @n_remainingqty = @n_remainingqty - (QTY - QTYPICKED)
                        FROM SKUxLOC (NOLOCK)
                        WHERE StorerKey = @c_CurrentStorer
                        AND SKU = @c_currentSKU
                        AND LOC = @c_currentloc
                     END

                     WHILE (1=1)
                     BEGIN
                        /* See if there are any lots where the QTY is overalLOCated... */
                        /* if Yes then uses this lot first... */
                        -- That means that the last try at this section of code was successful therefore try again.
                        IF @b_DoneCheckOverAllocatedLots = 0
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot2 = LOTxLOCxID.LOT
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot2
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_currentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LocationFlag <> "DAMAGE"
                           AND LOC.LocationFlag <> "HOLD"
                           AND LOTxLOCxID.qtyexpected > 0
                           AND LOTxLOCxID.LOC = @c_currentLOC
                           AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                           AND LOC.Facility = @c_Zone01
                           ORDER BY LOTTABLE04, LOTTABLE05
                           IF @@ROWCOUNT = 0
                           BEGIN
                              SELECT @b_DoneCheckOverAllocatedLots = 1
                              SELECT @c_fromlot = ""
                           END
                        ELSE
                           SELECT @b_DoneCheckOverAllocatedLots = 1
                        END --IF @b_DoneCheckOverAllocatedLots = 0
                        /* End see if there are any lots where the QTY is overalLOCated... */
                        SET ROWCOUNT 0
                        /* If there are not lots overalLOCated in the candidate LOCation, simply pull lots into the LOCation by lot # */
                        IF @b_DoneCheckOverAllocatedLots = 1
                        BEGIN
                           /* Select any lot if no lot was over alLOCated */
                           SET ROWCOUNT 1
                           SELECT @c_fromlot = LOTxLOCxID.LOT
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_currentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LocationFlag <> "DAMAGE"
                           AND LOC.LocationFlag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                           AND LOTxLOCxID.LOC <> @c_currentLOC
                           AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                           AND  LOC.Facility = @c_Zone01
                           ORDER BY LOTTABLE04, LOTTABLE05
                           IF @@ROWCOUNT = 0
                           BEGIN
                              IF @b_debug = 1
                              SELECT 'Not Lot Available! SKU= ' + @c_currentSKU + ' LOC=' + @c_currentLOC + ' From Lot=' + @c_fromlot
                              SET ROWCOUNT 0
                              BREAK
                           END
                        ELSE
                           BEGIN
                              IF @b_debug = 1
                              SELECT 'Lot Found! SKU= ' + dbo.fnc_RTrim(@c_currentSKU) + ' LOC = ' + @c_currentLOC + ' From Lot=' + @c_fromlot
                              SET ROWCOUNT 0
                           END
                           SET ROWCOUNT 0
                        END
                     ELSE
                        BEGIN
                           SELECT @c_fromlot = @c_fromlot2
                        END -- IF @b_DoneCheckOverAllocatedLots = 1
                        SET ROWCOUNT 0
                        SELECT @c_fromLOC = SPACE(10)
                        WHILE (1=1 AND @n_remainingqty > 0)
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
                           AND LOC.LocationFlag <> "DAMAGE"
                           AND LOC.LocationFlag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                           AND LOTxLOCxID.LOC <> @c_currentLOC
                           AND  LOC.Facility = @c_Zone01
                           ORDER BY LOTxLOCxID.LOC
                           IF @@ROWCOUNT = 0
                           BEGIN
                              SET ROWCOUNT 0
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because No Loc Found! LOC = ' + @c_currentLOC + ' SKU = ' + @c_currentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_fromLOC
                                 + ' From ID = ' + @c_fromid
                              END
                              BREAK
                           END
                           SET ROWCOUNT 0
                           SELECT @c_fromid = replicate('Z',18)
                           WHILE (1=1 AND @n_remainingqty > 0)
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
                              AND LOC.LocationFlag <> "DAMAGE"
                              AND LOC.LocationFlag <> "HOLD"
                              AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                              AND LOTxLOCxID.LOC <> @c_currentLOC
                              AND  LOC.Facility = @c_Zone01
                              ORDER BY ID DESC
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
                              AND LocationType = "PICK"
                              )
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
                              AND LocationType = "CASE"
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
                              SELECT @n_SKULocAvailableQty = QTY - QTYALLOCATED - QTYPICKED
                              FROM SKUxLOC (NOLOCK)
                              WHERE StorerKey = @c_CurrentStorer
                              AND SKU = @c_currentSKU
                              AND LOC = @c_fromLOC
                              IF @n_SKULocAvailableQty < @n_OnHandQty
                              BEGIN
                                 SELECT @n_OnHandQty = @n_SKULocAvailableQty
                              END
                              /* How many cases can I get from this record? */
                              SELECT @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullCase)
                              /* How many do we take? */
                              IF @n_OnHandQty > @n_RemainingQty
                              BEGIN
                                 -- Modify by SHONG for full carton only
                                 SELECT @n_FromQty = @n_RemainingQty,
                                 -- SELECT @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase),
                                 -- @n_remainingqty = @n_remainingqty - (@n_remainingcases * @n_CurrentFullCase),
                                 @n_RemainingQty = 0
                              END
                           ELSE
                              BEGIN
                                 -- Modify by shong for full carton only
                                 SELECT @n_FromQty = @n_OnHandQty,
                                 -- @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase),
                                 @n_remainingqty = @n_remainingqty - @n_OnHandQty
                                 -- @n_remainingqty = @n_remainingqty - @n_FromQty
                                 -- @n_remainingcases =  @n_remainingcases - @n_PossibleCases
                              END
                              IF @n_FromQty > 0
                              BEGIN
                                 SELECT @c_Packkey = PACK.PackKey,
                                 @c_UOM = PACK.PackUOM3
                                 FROM   SKU (NOLOCK), PACK (NOLOCK)
                                 WHERE  SKU.PackKey = PACK.Packkey
                                 AND    SKU.StorerKey = @c_CurrentStorer
                                 AND    SKU.SKU = @c_currentSKU
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
                               select @c_currentSKU ' SKU', @c_currentLOC 'LOC', @c_CurrentPriority 'priority', @n_CurrentFullCase 'full case', @n_CurrentSeverity 'severity'
                                 -- select @n_FromQty 'qty', @c_fromLOC 'fromLOC', @c_fromlot 'from lot', @n_PossibleCases 'possible cases'
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

      DECLARE CUR1 CURSOR  FAST_FORWARD READ_ONLY FOR
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM
      FROM #REPLENISHMENT R


      OPEN CUR1
      FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
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
            'N')
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63524   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into live pickdetail table failed.  Preallocated QTY Needs to be Manually Adjusted! (nspOrderProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END -- IF @b_success = 1
         FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
      END -- While
      DEALLOCATE CUR1
      -- End Insert Replenishment
      IF @n_continue=3  -- Error Occured - Process And Return
      BEGIN
         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishmentRpt_PC'
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
   --(Wan01) - START
   QUIT_SP:
      IF @c_FuncType IN ( 'G' )                                     
      BEGIN
         RETURN                                                             
      END
   --(Wan01) - END

      IF ( @c_zone02 = 'ALL')
      BEGIN
         SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
         SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey,
         R.AddDate, R.AddWho, R.EditDate, R.EditWho
         FROM  REPLENISHMENT R (NOLOCK), SKU (NOLOCK), LOC (NOLOCK), PACK (NOLOCK) -- Pack table added by Jacob Date Jan 03, 2001
         WHERE SKU.Sku = R.Sku
         AND  SKU.StorerKey = R.StorerKey
         AND  LOC.Loc = R.ToLoc
         AND  SKU.PackKey = PACK.PackKey
         AND  R.Confirmed = 'N'
         AND  LOC.Facility = @c_Zone01
         AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)
         AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)
         ORDER BY LOC.PutawayZone, R.Priority
      END
   ELSE
      BEGIN
         SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
         SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey,
         R.AddDate, R.AddWho, R.EditDate, R.EditWho
         FROM  REPLENISHMENT R (NOLOCK), SKU (NOLOCK), LOC (NOLOCK), PACK (NOLOCK) -- Pack table added by Jacob Date Jan 03, 2001
         WHERE SKU.Sku = R.Sku
         AND  SKU.StorerKey = R.StorerKey
         AND  LOC.Loc = R.ToLoc
         AND  SKU.PackKey = PACK.PackKey
         AND  R.Confirmed = 'N'
         AND  LOC.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         AND  LOC.Facility = @c_Zone01
         AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)
         AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)
         ORDER BY LOC.PutawayZone, R.Priority
      END
   END

GO