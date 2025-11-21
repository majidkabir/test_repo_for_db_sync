SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

-- Modification History
-- Phase 5.1 TBL HK FBR10317
-- Add From Loc Qty into Result Set

-- Modify By SHONG on 20th May 2003
-- Bug Fixing
CREATE PROC  [dbo].[nsp_ReplenishmentRpt_RF_TBL]
@c_facility         NVARCHAR(5)
,              @c_FromStorerKey    NVARCHAR(15)
,              @c_ToStorerKey      NVARCHAR(15)
,              @c_zone01           NVARCHAR(10)
,              @c_zone02           NVARCHAR(10)
,              @c_zone03           NVARCHAR(10)
,              @c_zone04           NVARCHAR(10)
,              @c_zone05           NVARCHAR(10)
,              @c_FromAisle        NVARCHAR(10)
,              @c_ToAisle          NVARCHAR(10)
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
@c_UOM     NVARCHAR(10) -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)


SELECT @n_continue=1,
@b_debug = 0

--      IF @c_zone12 <> ''
--         SELECT @b_debug = CAST( @c_zone12 AS int)

DECLARE @c_priority  NVARCHAR(5),
        @n_skulocavailableqty int -- TBL HK
SELECT StorerKey, Sku, Loc FromLoc, Loc ToLoc, Lot, Id, Qty, Qty QtyMoved, Qty QtyInPickLoc,
@c_priority Priority, Lot UOM, Lot PackKey,@n_skulocavailableqty skulocqty -- TBL HK
INTO #REPLENISHMENT
FROM LOTXLOCXID (NOLOCK)
WHERE 1 = 2


IF @n_continue = 1 or @n_continue = 2
BEGIN
DECLARE @c_currentsku NVARCHAR(20), @c_currentstorer NVARCHAR(15),
@c_currentloc NVARCHAR(10), @c_currentpriority NVARCHAR(5),
@n_currentfullcase int, @n_currentseverity int,
@c_fromloc NVARCHAR(10), @c_fromlot NVARCHAR(10), @c_fromid NVARCHAR(18),
@n_fromqty int, @n_remainingqty int, @n_possiblecases int ,
@n_remainingcases int, @n_OnHandQty int, @n_fromcases int ,
@c_ReplenishmentKey NVARCHAR(10), @n_numberofrecs int, @n_limitrecs int,
@c_fromlot2 NVARCHAR(10),
@b_donecheckoverallocatedlots int

SELECT @c_currentsku = SPACE(20), @c_currentstorer = SPACE(15),
@c_currentloc = SPACE(10), @c_currentpriority = SPACE(5),
@n_currentfullcase = 0   , @n_currentseverity = 9999999 ,
@n_fromqty = 0, @n_remainingqty = 0, @n_possiblecases = 0,
@n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,
@n_limitrecs = 5


/* Make a temp version of skuxloc */
SELECT REPLENISHMENTPRIORITY, REPLENISHMENTSEVERITY,STORERKEY,
		 SKU, LOC, REPLENISHMENTCASECNT
INTO #tempskuxloc
FROM SKUxLOC (NOLOCK)
WHERE 1=2

IF (@c_zone01 = 'ALL')
BEGIN
   INSERT #tempskuxloc
   SELECT 1 AS replenishmentpriority, 
			(SKUxLOC.QtyLocationLimit - SKUxLOC.Qty - SKUxLOC.QtyPicked) AS replenishmentseverity, 
			storerkey, sku, SKUxLOC.loc, 1 AS replenishmentcasecnt
   FROM SKUxLOC (NOLOCK), LOC (NOLOCK)
   WHERE (skuxloc.locationtype = 'PICK' or skuxloc.locationtype = 'CASE')
   AND  (SKUxLOC.Qty - SKUxLOC.QtyPicked) <= SKUxLOC.QtyLocationMinimum
   AND  (SKUxLOC.QtyLocationLimit - SKUxLOC.Qty - SKUxLOC.QtyPicked) > 0 
   AND  SKUxLOC.LOC = LOC.LOC
   AND  LOC.Locationflag <> 'DAMAGE'
   AND  LOC.Locationflag <> 'HOLD'
   AND  LOC.Facility = @c_facility
   AND  SKUxLOC.StorerKey between @c_FromStorerKey And @c_ToStorerKey
   AND  LOC.LocAisle between @c_FromAisle and @c_ToAisle
END
ELSE
BEGIN
   INSERT #tempskuxloc
   SELECT 1 AS replenishmentpriority, 
			(SKUxLOC.QtyLocationLimit - SKUxLOC.Qty - SKUxLOC.QtyPicked) AS replenishmentseverity, 
			storerkey, sku, SKUxLOC.loc, 1 AS replenishmentcasecnt
   FROM SKUxLOC (NOLOCK), LOC (NOLOCK)
   WHERE (skuxloc.locationtype = 'PICK' or skuxloc.locationtype = 'CASE')
   AND  (SKUxLOC.Qty - SKUxLOC.QtyPicked) <= SKUxLOC.QtyLocationMinimum
   AND  (SKUxLOC.QtyLocationLimit - SKUxLOC.Qty - SKUxLOC.QtyPicked) > 0 
   AND  SKUxLOC.LOC = LOC.LOC
   AND  LOC.Locationflag <> 'DAMAGE'
   AND  LOC.Locationflag <> 'HOLD'
   AND  LOC.Facility = @c_facility
   AND  SKUxLOC.StorerKey between @c_FromStorerKey And @c_ToStorerKey
   AND  LOC.LocAisle between @c_FromAisle and @c_ToAisle
   AND  LOC.putawayzone in (@c_zone01, @c_zone02, @c_zone03, @c_zone04, @c_zone05)
END

IF @b_debug = 1
BEGIN
   Print 'Before Filtering....'
   SELECT * FROM #tempskuxloc
END 
-- Added By SHONG
-- Date: 16th JUL 2001
-- Purpose: To Speed up the process
-- Remove all the rows that got not inventory to replenish
DECLARE @c_StorerKey  NVARCHAR(15),
      @c_SKU		  NVARCHAR(20),
      @c_LOC        NVARCHAR(10)

DECLARE CUR1 CURSOR  FAST_FORWARD READ_ONLY FOR
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
                  AND   LOC.Facility = @c_facility)
   BEGIN
      DELETE #tempskuxloc
      WHERE Storerkey = @c_StorerKey
      AND   SKU = @c_SKU	
   END
   FETCH NEXT FROM CUR1 INTO @c_StorerKey, @c_SKU, @c_LOC
END
DEALLOCATE CUR1

IF @b_debug = 1
BEGIN
   Print 'After Filtering....'
   SELECT * FROM #tempskuxloc
END 
				
WHILE (1=1)
BEGIN
   SET ROWCOUNT 1
   
   SELECT @c_currentpriority = replenishmentpriority
   FROM #tempskuxloc
   WHERE replenishmentpriority > @c_currentpriority
   AND  replenishmentcasecnt > 0
   ORDER BY replenishmentpriority

   IF @@ROWCOUNT = 0
   BEGIN
      SET ROWCOUNT 0
      BREAK
   END
   SET ROWCOUNT 0
   
   /* Loop through skuxloc for the currentsku, current storer */
   /* to pickup the next severity */
   SELECT @n_currentseverity = 999999999
   WHILE (1=1)
   BEGIN
      SET ROWCOUNT 1
      SELECT @n_currentseverity = replenishmentseverity
      FROM #tempskuxloc
      WHERE replenishmentseverity < @n_currentseverity
      AND replenishmentpriority = @c_currentpriority
      AND  replenishmentcasecnt > 0
      ORDER BY replenishmentseverity DESC
      IF @@ROWCOUNT = 0
      BEGIN
         SET ROWCOUNT 0
         BREAK
      END
      SET ROWCOUNT 0

      /* Now - for this priority, this severity - find the next storer row */
      /* that matches */
      SELECT @c_currentsku = SPACE(20), @c_currentstorer = SPACE(15),
      @c_currentloc = SPACE(10)
      WHILE (1=1)
      BEGIN
         SET ROWCOUNT 1
         SELECT @c_currentstorer = storerkey
         FROM #tempskuxloc
         WHERE storerkey > @c_currentstorer
         AND replenishmentseverity = @n_currentseverity
         AND replenishmentpriority = @c_currentpriority
         ORDER BY Storerkey
         IF @@ROWCOUNT = 0
         BEGIN
            SET ROWCOUNT 0
            BREAK
         END
         SET ROWCOUNT 0

         /* Now - for this priority, this severity - find the next sku row */
         /* that matches */
         SELECT @c_currentsku = SPACE(20),
         @c_currentloc = SPACE(10)
         WHILE (1=1)
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_currentstorer = storerkey ,
            @c_currentsku = sku,
            @c_currentloc = loc,
            @n_currentfullcase = 1 -- SKUxLOC.ReplenishmentCaseCnt
            FROM #tempskuxloc
            WHERE sku > @c_currentsku
            AND storerkey = @c_currentstorer
            AND replenishmentseverity = @n_currentseverity
            AND replenishmentpriority = @c_currentpriority
            ORDER BY sku
            
            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0

            /* We now have a picklocation that needs to be replenished! */
            /* Figure out which locations in the warehouse to pull this product from */
            /* End figure out which locations in the warehouse to pull this product from */

            SELECT @c_fromloc = SPACE(10),  @c_fromlot = SPACE(10), @c_fromid = SPACE(18),
            @n_fromqty = 0, @n_possiblecases = 0,
            @n_remainingqty = @n_currentseverity * @n_currentfullcase,
            @n_remainingcases = @n_currentseverity,
            @c_fromlot2 = SPACE(10),
            @b_donecheckoverallocatedlots = 0

            WHILE (1=1)
            BEGIN
            /* See if there are any lots where the QTY is overallocated... */
            /* if Yes then uses this lot first... */
            -- That means that the last try at this section of code was successful therefore try again.
            IF @b_donecheckoverallocatedlots = 0
            BEGIN
               IF @c_zone01 = 'ALL'
               BEGIN
               SET ROWCOUNT 1
               SELECT @c_fromlot2 = LOTxLOCxID.LOT
               FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK)
               WHERE LOTxLOCxID.LOT > @c_fromlot2
               AND LOTxLOCxID.storerkey = @c_currentstorer
               AND LOTxLOCxID.sku = @c_currentsku
               AND LOTxLOCxID.Loc = LOC.LOC
               AND LOTxLOCxID.Lot = LOT.Lot
               AND LOTATTRIBUTE.Lot = LOT.Lot
               AND LOT.Status = 'OK'
               AND LOC.Locationflag <> 'DAMAGE'
               AND LOC.Locationflag <> 'HOLD'
               AND LOTxLOCxID.qtyexpected > 0
               AND LOTxLOCxID.loc = @c_currentloc
               AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
               AND LOC.Facility = @c_facility
               -- added by Jeff, do not include expired products
               AND LOTATTRIBUTE.Lottable04 > getdate()
               ORDER BY LOTTABLE04, LOTTABLE02, LOTTABLE05, LOTATTRIBUTE.LOT
            END
            ELSE
            BEGIN
               SET ROWCOUNT 1
               SELECT @c_fromlot2 = LOTxLOCxID.LOT
               FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK)
               WHERE LOTxLOCxID.LOT > @c_fromlot2
               AND LOTxLOCxID.storerkey = @c_currentstorer
               AND LOTxLOCxID.sku = @c_currentsku
               AND LOTxLOCxID.Loc = LOC.LOC
               AND LOTxLOCxID.Lot = LOT.Lot
               AND LOTATTRIBUTE.Lot = LOT.Lot
               AND LOT.Status = 'OK'
               AND LOC.Locationflag <> 'DAMAGE'
               AND LOC.Locationflag <> 'HOLD'
               AND LOTxLOCxID.qtyexpected > 0
               AND LOTxLOCxID.loc = @c_currentloc
               AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
               AND LOC.Facility = @c_facility
               -- added by Jeff, do not include expired products
               AND LOTATTRIBUTE.Lottable04 > getdate()
               ORDER BY LOTTABLE04, LOTTABLE02, LOTTABLE05, LOTATTRIBUTE.LOT
               END
               IF @@ROWCOUNT = 0
               BEGIN
                  SELECT @b_donecheckoverallocatedlots = 1
                  SELECT @c_fromlot = ''
               END
               ELSE
                  SELECT @b_donecheckoverallocatedlots = 1
            END --IF @b_donecheckoverallocatedlots = 0
            /* End see if there are any lots where the QTY is overallocated... */
            SET ROWCOUNT 0
            /* If there are not lots overallocated in the candidate location, simply pull lots into the location by lot # */
            IF @b_donecheckoverallocatedlots = 1
            BEGIN
            /* Select any lot if no lot was over allocated */
               IF @c_zone01 = 'ALL'
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_fromlot = LOTxLOCxID.LOT
                  FROM LOTxLOCxID  (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK)
                  WHERE LOTxLOCxID.LOT > @c_fromlot
                  AND LOTxLOCxID.storerkey = @c_currentstorer
                  AND LOTxLOCxID.sku = @c_currentsku
                  AND LOTxLOCxID.Loc = LOC.LOC
                  AND LOTxLOCxID.Lot = LOT.Lot
                  AND LOTATTRIBUTE.Lot = LOT.Lot
                  AND LOT.Status = 'OK'
                  AND LOC.Locationflag <> 'DAMAGE'
                  AND LOC.Locationflag <> 'HOLD'
                  AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.qtyallocated > 0
                  AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND
                  AND LOTxLOCxID.loc <> @c_currentloc
                  AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                  AND LOC.Facility = @c_facility
                  -- added by Jeff, do not include expired products
                  AND (LOTATTRIBUTE.Lottable04 > getdate() OR LOTATTRIBUTE.Lottable04 IS NULL)
                  ORDER BY LOTTABLE04, LOTTABLE02, LOTTABLE05, LOTATTRIBUTE.LOT
               END
               ELSE
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_fromlot = LOTxLOCxID.LOT
                  FROM LOTxLOCxID  (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK)
                  WHERE LOTxLOCxID.LOT > @c_fromlot
                  AND LOTxLOCxID.storerkey = @c_currentstorer
                  AND LOTxLOCxID.sku = @c_currentsku
                  AND LOTxLOCxID.Loc = LOC.LOC
                  AND LOTxLOCxID.Lot = LOT.Lot
                  AND LOTATTRIBUTE.Lot = LOT.Lot
                  AND LOT.Status = 'OK'
                  AND LOC.Locationflag <> 'DAMAGE'
                  AND LOC.Locationflag <> 'HOLD'
                  AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.qtyallocated > 0
                  AND LOTxLOCxID.qtyexpected = 0
                  AND LOTxLOCxID.loc <> @c_currentloc
                  AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                  AND LOC.Facility = @c_facility
                  -- added by Jeff, do not include expired products
                  AND (LOTATTRIBUTE.Lottable04 > getdate() OR LOTATTRIBUTE.Lottable04 IS NULL)
                  ORDER BY LOTTABLE04, LOTTABLE02, LOTTABLE05, LOTATTRIBUTE.LOT
               END
               IF @@ROWCOUNT = 0
               BEGIN
                  IF @b_debug = 1
                     SELECT 'Not Lot Available! SKU= ' + @c_currentsku + ' LOC=' + @c_currentloc
                  SET ROWCOUNT 0
                  BREAK
               END
               SET ROWCOUNT 0
            END
            ELSE
            BEGIN
               SELECT @c_fromlot = @c_fromlot2
            END -- IF @b_donecheckoverallocatedlots = 1
            SET ROWCOUNT 0
            SELECT @c_fromloc = SPACE(10)
            WHILE (1=1 AND @n_remainingqty > 0)
            BEGIN
               IF @c_zone01 = 'ALL'
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_fromloc = LOTxLOCxID.LOC
                  FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOT (NOLOCK)
                  WHERE LOTxLOCxID.LOT = @c_fromlot
                  AND LOTxLOcxID.loc = LOC.loc
                  AND LOTxLOCxID.LOC > @c_fromloc
                  AND LOTxLOCxID.storerkey = @c_currentstorer
                  AND LOTxLOCxID.sku = @c_currentsku
                  AND LOTxLOCxID.Loc = LOC.LOC
                  AND LOTxLOCxID.Lot = LOT.Lot
                  AND LOT.Status = 'OK'
                  AND LOC.Locationflag <> 'DAMAGE'
                  AND LOC.Locationflag <> 'HOLD'
                  AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.qtyallocated > 0
                  AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND
                  AND LOTxLOCxID.loc <> @c_currentloc
                  AND LOC.Facility = @c_facility
                  ORDER BY LOTxLOCxID.LOC
               END
               ELSE
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_fromloc = LOTxLOCxID.LOC
                  FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOT (NOLOCK)
                  WHERE LOTxLOCxID.LOT = @c_fromlot
                  AND LOTxLOcxID.loc = LOC.loc
                  AND LOTxLOCxID.LOC > @c_fromloc
                  AND LOTxLOCxID.storerkey = @c_currentstorer
                  AND LOTxLOCxID.sku = @c_currentsku
                  AND LOTxLOCxID.Loc = LOC.LOC
                  AND LOTxLOCxID.Lot = LOT.Lot
                  AND LOT.Status = 'OK'
                  AND LOC.Locationflag <> 'DAMAGE'
                  AND LOC.Locationflag <> 'HOLD'
                  AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.qtyallocated > 0
                  AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND
                  AND LOTxLOCxID.loc <> @c_currentloc
                  AND LOC.Facility = @c_facility
                  ORDER BY LOTxLOCxID.LOC
                  END
                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET ROWCOUNT 0
                     BREAK
                  END
               SET ROWCOUNT 0
               SELECT @c_fromid = replicate('Z',18)
               WHILE (1=1 AND @n_remainingqty > 0)
               BEGIN
                  IF @c_zone01 = 'ALL'
                  BEGIN
                     SET ROWCOUNT 1
                     SELECT @c_fromid = ID,
                     @n_OnHandQty = LOTxLOCxID.QTY - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYALLOCATED
                     FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOT (NOLOCK)
                     WHERE LOTxLOCxID.LOT = @c_fromlot
                     AND LOTxLOcxID.loc = LOC.loc
                     AND LOTxLOCxID.LOC = @c_fromloc
                     AND id < @c_fromid
                     AND LOTxLOCxID.storerkey = @c_currentstorer
                     AND LOTxLOCxID.sku = @c_currentsku
                     AND LOTxLOCxID.Lot = LOT.Lot
                     AND LOT.Status = 'OK'
                     AND  LOC.Locationflag <> 'DAMAGE'
                     AND  LOC.Locationflag <> 'HOLD'
                     AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.qtyallocated > 0
                     AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND
                     AND LOTxLOCxID.loc <> @c_currentloc
                     AND LOC.Facility = @c_facility
                     ORDER BY ID DESC
                  END
               ELSE
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_fromid = ID,
                  @n_OnHandQty = LOTxLOCxID.QTY - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYALLOCATED
                  FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOT (NOLOCK)
                  WHERE LOTxLOCxID.LOT = @c_fromlot
                  AND LOTxLOcxID.loc = LOC.loc
                  AND LOTxLOCxID.LOC = @c_fromloc
                  AND id < @c_fromid
                  AND LOTxLOCxID.storerkey = @c_currentstorer
                  AND LOTxLOCxID.sku = @c_currentsku
                  AND LOTxLOCxID.Lot = LOT.Lot
                  AND LOT.Status = 'OK'
                  AND LOC.Locationflag <> 'DAMAGE'
                  AND LOC.Locationflag <> 'HOLD'
                  AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.qtyallocated > 0
                  AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND
                  AND LOTxLOCxID.loc <> @c_currentloc
                  AND LOC.Facility = @c_facility
                  ORDER BY ID DESC
               END
               IF @@ROWCOUNT = 0
               BEGIN
        IF @b_debug = 1
                  BEGIN
                     SELECT 'Stop because No Pallet Found! Loc = ' + @c_currentloc + ' SKU = ' + @c_currentsku + ' LOT = ' + @c_fromlot + ' From Loc = ' + @c_fromloc
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
/* SQL SERVER seems to work best on a maximum of a */
/* 4-way join. */
IF EXISTS(SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_fromid
AND STATUS = 'HOLD')
BEGIN
IF @b_debug = 1
BEGIN
SELECT 'Stop because location Status = HOLD! Loc = ' + @c_currentloc + ' SKU = ' + @c_currentsku + ' ID = ' + @c_fromid
END
BREAK -- Get out of loop, so that next cANDidate can be evaluated
END
/* Verify that the from location is not overallocated in skuxloc */
IF EXISTS(SELECT 1 FROM SKUxLOC  (NOLOCK)
WHERE STORERKEY = @c_currentstorer
AND SKU = @c_currentsku
AND LOC = @c_fromloc
AND QTYEXPECTED > 0
)
BEGIN
IF @b_debug = 1
BEGIN
SELECT 'Stop because Qty Expected > 0! Loc = ' + @c_currentloc + ' SKU = ' + @c_currentsku
END
BREAK -- Get out of loop, so that next cANDidate can be evaluated
END
/* Verify that the FROM location is not the */
/* PIECE PICK location for this product.    */
IF EXISTS(SELECT 1 FROM SKUxLOC  (NOLOCK)
WHERE STORERKEY = @c_currentstorer
AND SKU = @c_currentsku
AND LOC = @c_fromloc
AND LOCATIONTYPE = 'PICK'
)
BEGIN
IF @b_debug = 1
BEGIN
SELECT 'Stop because location Type = PICK! Loc = ' + @c_currentloc + ' SKU = ' + @c_currentsku
END
BREAK -- Get out of loop, so that next cANDidate can be evaluated
END
/* Verify that the FROM location is not the */
/* CASE PICK location for this product.     */
IF EXISTS(SELECT 1 FROM SKUxLOC  (NOLOCK)
WHERE STORERKEY = @c_currentstorer
AND SKU = @c_currentsku
AND LOC = @c_fromloc
AND LOCATIONTYPE = 'CASE'
)
BEGIN
IF @b_debug = 1
BEGIN
SELECT 'Stop because location Type = CASE! Loc = ' + @c_currentloc + ' SKU = ' + @c_currentsku
END
BREAK -- Get out of loop, so that next cANDidate can be evaluated
END
/* At this point, get the available qty from */
/* the SKUxLOC record.                       */
/* If it's less than what was taken from the */
/* lotxlocxid record, then use it.           */
SELECT @n_skulocavailableqty = QTY - QTYALLOCATED - QTYPICKED
FROM SKUxLOC (NOLOCK)
WHERE STORERKEY = @c_currentstorer
AND SKU = @c_currentsku
AND LOC = @c_fromloc
IF @n_skulocavailableqty < @n_OnHandQty
BEGIN
SELECT @n_OnHandQty = @n_skulocavailableqty
END
/* How many cases can I get from this record? */
SELECT @n_possiblecases = floor(@n_OnHandQty / @n_currentfullcase)

/* How many do we take? */
IF @n_OnHandQty > @n_RemainingQty
BEGIN
SELECT @n_fromqty = @n_RemainingQty,
-- @n_remainingqty = @n_remainingqty - (@n_remainingcases * @n_currentfullcase),
@n_RemainingQty = 0
END
ELSE
BEGIN
SELECT @n_fromqty = @n_OnHandQty,
@n_remainingqty = @n_remainingqty - @n_OnHandQty
-- @n_remainingcases =  @n_remainingcases - @n_possiblecases
END
IF @n_fromqty > 0
BEGIN
SELECT @c_Packkey = PACK.PackKey,
@c_UOM = PACK.PackUOM3
FROM   SKU (NOLOCK), PACK (NOLOCK)
WHERE  SKU.PackKey = PACK.Packkey
AND    SKU.StorerKey = @c_currentStorer
AND    SKU.SKU = @c_currentSku
IF @n_continue = 1 or @n_continue = 2
BEGIN
INSERT #REPLENISHMENT (
StorerKey,
Sku,
FromLoc,
ToLoc,
Lot,
Id,
Qty,
UOM,
PackKey,
Priority,
QtyMoved,
QtyInPickLoc,
skulocqty) --TBL HK
VALUES (
@c_currentStorer,
@c_currentSku,
@c_fromLoc,
@c_currentLoc,
@c_fromlot,
@c_fromid,
@n_fromqty,
@c_UOM,
@c_Packkey,
@c_currentpriority,
0,0,
@n_skulocavailableqty) --TBL HK
END
SELECT @n_numberofrecs = @n_numberofrecs + 1
END -- if from qty > 0
IF @b_debug = 1
BEGIN
select @c_currentsku ' sku', @c_currentloc 'loc', @c_currentpriority 'priority', @n_currentfullcase 'full case', @n_currentseverity 'severity'
-- select @n_fromqty 'qty', @c_fromloc 'fromloc', @c_fromlot 'from lot', @n_possiblecases 'possible cases'
select @n_remainingqty '@n_remainingqty', @c_currentloc + ' SKU = ' + @c_currentsku, @c_fromlot 'from lot', @c_fromid
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
END -- (WHILE 1=1 on SKUxLOC FOR PRIORITY )
SET ROWCOUNT 0
END

IF @n_continue=1 OR @n_continue=2
BEGIN
/* Update the column QtyInPickLoc in the Replenishment Table */
IF @n_continue = 1 or @n_continue = 2
BEGIN
UPDATE #REPLENISHMENT SET QtyInPickLoc = SkuxLoc.Qty - SkuxLoc.QtyPicked
FROM SKUxLOC (NOLOCK)
WHERE #REPLENISHMENT.Storerkey = Skuxloc.Storerkey AND
#REPLENISHMENT.SKu = Skuxloc.Sku AND
#REPLENISHMENT.toloc = SkuxLoc.loc
END
END


SELECT R.FromLoc,
R.Id,
R.ToLoc,
R.Sku,
R.Qty,
R.StorerKey,
R.Lot,
R.PackKey,
SKU.Descr,
SKU.lottable02label,  -- modify by MMLEE for HK FBR098 on 20020327
R.Priority,
LOC.PutawayZone,
LA.Lottable01,
LA.Lottable02,
LA.Lottable03,
LA.Lottable04,
LA.Lottable05,
PACK.CaseCnt,
LOC.Facility,
A.PutawayZone AS FromZone,
PACK.Pallet,
(CASE WHEN R.ID <> '' AND L.Qty = R.Qty THEN 'Pallet'
WHEN R.ID = '' AND R.Qty >= PACK.Pallet THEN 'Pallet'
ELSE 'Case'
END) AS Type,
R.skulocqty, --TBL HK
SKU.BUSR1 -- TBL HK
FROM #REPLENISHMENT R
JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = R.StorerKey AND SKU.SKU = R.Sku)
JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
JOIN LOC WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
JOIN LOC A WITH (NOLOCK) ON (A.LOC = R.FROMLOC)
JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = R.LOT)
JOIN LOTxLOCxID L WITH (NOLOCK) ON (L.LOT = R.LOT AND L.Loc = R.FromLOC AND L.ID = R.ID)
END


GO