SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFRP01                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/


CREATE	PROC    nspRFRP01
@c_senddelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(10)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_zone01           NVARCHAR(10)
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
,              @c_outstring        NVARCHAR(255) OUTPUT
,              @b_Success          int       OUTPUT
,              @n_err              int       OUTPUT
,              @c_errmsg           NVARCHAR(250) OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   /* Modification history
   26 July 2000  - Modified for Taiwan. The first field in the RF Replenishment will be used for facility code
   - the second field will accept the argument 'ALL' for zone
   - the rest of the fields will be the same as BASE.
   */
   DECLARE        @n_continue int        ,  /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int,              -- For Additional Error Detection
   @b_debug int              -- Debug Flag
   /* Declare RF Specific Variables */
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @c_dbnamestring NVARCHAR(255)
   DECLARE @n_cqty int, @n_returnrecs int
   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=0
   SELECT @b_debug = 0
   /* RC01 Specific Variables */
   DECLARE @c_itrnkey NVARCHAR(10)
   /* Calculate next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      EXECUTE nspg_GetKey
      @keyname       = "REPLENISHGROUP",
      @fieldlength   = 10,
      @keystring     = @c_taskid    OUTPUT,
      @b_success     = @b_success   OUTPUT,
      @n_err         = @n_err       OUTPUT,
      @c_errmsg      = @c_errmsg    OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   /* End Calculate Next Task ID */
   /* Clear this PTCID from the REPLENISHMENT_LOCK Table */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DELETE FROM REPLENISHMENT_LOCK
      WHERE PTCID = @c_ptcid or
      datediff(second,adddate,getdate()) > 900  -- 15 minutes
   END
   -- make sure the first argument is included. This is for facility
   IF @c_zone01 = '' or @c_zone01 is null
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 65201
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+":  Column Facility is required (nspRFRP01)"
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_currentsku NVARCHAR(20), @c_currentstorer NVARCHAR(15),
      @c_currentloc NVARCHAR(10), @c_currentpriority NVARCHAR(5),
      @n_currentfullcase int, @n_currentseverity int,
      @c_fromloc NVARCHAR(10), @c_fromlot NVARCHAR(10), @c_fromid NVARCHAR(18),
      @n_fromqty int, @n_remainingqty int, @n_possiblecases int ,
      @n_remainingcases int, @n_onhandqty int, @n_fromcases int ,
      @c_ReplenishmentKey NVARCHAR(10), @n_numberofrecs int, @n_limitrecs int,
      @c_fromlot2 NVARCHAR(10),
      @b_donecheckoverallocatedlots int,
      @n_skulocavailableqty int,
      @c_uom NVARCHAR(10)
      SELECT @c_currentsku = SPACE(20), @c_currentstorer = SPACE(15),
      @c_currentloc = SPACE(10), @c_currentpriority = SPACE(5),
      @n_currentfullcase = 0   , @n_currentseverity = 9999999 ,
      @n_fromqty = 0, @n_remainingqty = 0, @n_possiblecases = 0,
      @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,
      @n_limitrecs = 5
      /* Make a temp version of skuxloc */
      SELECT replenishmentpriority, replenishmentseverity ,storerkey,
      sku, loc, replenishmentcasecnt
      INTO #tempskuxloc
      FROM SKUxLOC (NOLOCK)
      WHERE 1=2
      IF (@c_zone02 = 'ALL')
      BEGIN
         -- the skuxloc.loc = loc.loc will fail if there are duplicate loc across different facility.
         INSERT #tempskuxloc
         SELECT replenishmentpriority, replenishmentseverity ,storerkey,
         sku, SKUXLOC.loc, replenishmentcasecnt
         FROM SKUxLOC (NOLOCK), LOC (NOLOCK)
         WHERE SKUXLOC.Loc = LOC.Loc
         AND (skuxloc.locationtype = "PICK" or skuxloc.locationtype = "CASE")
         and  replenishmentseverity > 0
         and  skuxloc.qty - skuxloc.qtypicked < skuxloc.QtyLocationMinimum -- skuxloc.qtylocationlimit
         -- AND SKUXLOC.Qty - SKUXLOC.QtyPicked
         AND LOC.Facility = @c_zone01
      END
   ELSE
      BEGIN
         INSERT #tempskuxloc
         SELECT replenishmentpriority, replenishmentseverity ,storerkey,
         sku, loc.loc, replenishmentcasecnt
         FROM SKUxLOC (NOLOCK), LOC (NOLOCK)
         WHERE SKUxLOC.LOC = LOC.LOC
         and  LOC.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         and  LOC.Locationflag <> "DAMAGE"
         and  LOC.Locationflag <> "HOLD"
         and  (skuxloc.locationtype = "PICK" or skuxloc.locationtype = "CASE")
         and  replenishmentseverity > 0
         and  skuxloc.qty - skuxloc.qtypicked < skuxloc.QtyLocationMinimum -- skuxloc.qtylocationlimit
         AND  loc.Facility = @c_zone01 -- added
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Cut 01'
         SELECT * FROM #TEMPSKUXLOC (NOLOCK)
      END
      WHILE (1=1 and @n_numberofrecs < @n_limitrecs )
      BEGIN
         IF @c_zone02 = "ALL"
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_currentpriority = replenishmentpriority
            FROM #tempskuxloc (NOLOCK)
            WHERE replenishmentpriority > @c_currentpriority
            and  replenishmentcasecnt > 0
            ORDER BY replenishmentpriority
         END
      ELSE
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_currentpriority = replenishmentpriority
            FROM #tempskuxloc (NOLOCK)
            WHERE replenishmentpriority > @c_currentpriority
            and  replenishmentcasecnt > 0
            ORDER BY replenishmentpriority
         END
         IF @@ROWCOUNT = 0
         BEGIN
            SET ROWCOUNT 0
            BREAK
         END
         SET ROWCOUNT 0
         /* Loop through skuxloc for the currentsku, current storer */
         /* to pickup the next severity */
         SELECT @n_currentseverity = 999999999
         WHILE (1=1 and @n_numberofrecs < @n_limitrecs )
         BEGIN
            SET ROWCOUNT 1
            SELECT @n_currentseverity = replenishmentseverity
            FROM #tempskuxloc (NOLOCK)
            WHERE replenishmentseverity < @n_currentseverity
            and replenishmentpriority = @c_currentpriority
            and  replenishmentcasecnt > 0
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
            WHILE (1=1 and @n_numberofrecs < @n_limitrecs )
            BEGIN
               SET ROWCOUNT 1
               SELECT @c_currentstorer = storerkey
               FROM #tempskuxloc (NOLOCK)
               WHERE storerkey > @c_currentstorer
               and replenishmentseverity = @n_currentseverity
               and replenishmentpriority = @c_currentpriority
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
               WHILE (1=1 and @n_numberofrecs < @n_limitrecs )
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_currentstorer = storerkey ,
                  @c_currentsku = sku,
                  @c_currentloc = loc,
                  @n_currentfullcase = replenishmentcasecnt
                  FROM #tempskuxloc (NOLOCK)
                  WHERE sku > @c_currentsku
                  and storerkey = @c_currentstorer
                  and replenishmentseverity = @n_currentseverity
                  and replenishmentpriority = @c_currentpriority
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
                  WHILE (1=1 and @n_remainingqty > 0 and @n_numberofrecs < @n_limitrecs )
                  BEGIN
                     /* See if there are any lots where the QTY is overallocated... */
                     IF @b_donecheckoverallocatedlots = 0 -- That means that the last try at this section of code was successful therefore try again.
                     BEGIN
                        IF @c_zone02 = "ALL"
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot2 = LOTxLOCxID.LOT
                           FROM LOTxLOCxID (NOLOCK) , LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot2
                           AND LOTxLOCxID.storerkey = @c_currentstorer
                           AND LOTxLOCxID.sku = @c_currentsku
                           AND LOTxLOCxID.Loc = LOC.LOC
                           AND LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
                           and  LOC.Locationflag <> "DAMAGE"
                           and  LOC.Locationflag <> "HOLD"
                           AND LOTxLOCxID.qtyexpected > 0
                           AND LOTxLOCxID.loc = @c_currentloc
                           ORDER BY lottable04, lottable05, lotxlocxid.LOT
                        END
                     ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot2 = LOTxLOCxID.LOT
                           FROM LOTxLOCxID (NOLOCK) , LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot2
                           AND LOTxLOCxID.storerkey = @c_currentstorer
                           AND LOTxLOCxID.sku = @c_currentsku
                           AND LOTxLOCxID.Loc = LOC.LOC
                           AND LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
                           AND LOTxLOCxID.qtyexpected > 0
                           AND LOTxLOCxID.loc = @c_currentloc
                           ORDER BY lottable04, lottable05, LOTxLOCxID.LOT
                        END
                        IF @@ROWCOUNT = 0
                        BEGIN
                           SELECT @b_donecheckoverallocatedlots = 1
                           SELECT @c_fromlot = ""
                        END
                     END --IF @b_donecheckoverallocatedlots = 0
                     /* End see if there are any lots where the QTY is overallocated... */
                     SET ROWCOUNT 0
                     /* If there are not lots overallocated in the candidate location, simply pull lots into the location by lot # */
                     IF @b_donecheckoverallocatedlots = 1
                     BEGIN
                        IF @c_zone02 = "ALL"
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot = LOTxLOCxID.LOT
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot
                           AND LOTxLOCxID.storerkey = @c_currentstorer
                           AND LOTxLOCxID.sku = @c_currentsku
                           AND LOTxLOCxID.Loc = LOC.LOC
                           AND LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
                           and  LOC.Locationflag <> "DAMAGE"
                           and  LOC.Locationflag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                           AND LOTxLOCxID.loc <> @c_currentloc
                           ORDER BY lottable04, lottable05, LOTxLOCxID.LOT
                        END
                     ELSE
                        BEGIN
                           IF @b_debug = 1
                           BEGIN
                              SELECT 'Enter Here'
                              select 'LOT 01', @c_fromlot
                              SELECT @c_fromlot = LOT
                              FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                              WHERE LOTxLOCxID.LOT > @c_fromlot
                              AND storerkey = @c_currentstorer
                              AND sku = @c_currentsku
                              AND LOTxLOCxID.Loc = LOC.LOC
                              /* Commented by CYOU - 13 Jul 2000 */
                              --                                                  AND LOC.putawayzone in ( @c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                              and  LOC.Locationflag <> "DAMAGE"
                              and  LOC.Locationflag <> "HOLD"
                              AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                              AND LOC.Facility = @c_zone01 -- make sure it pulls from the RIGHT FACILITY
                           END
                           SET ROWCOUNT 1
                           SELECT @c_fromlot = LOTxLOCxID.LOT
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot
                           AND LOTxLOCxID.storerkey = @c_currentstorer
                           AND LOTxLOCxID.sku = @c_currentsku
                           AND LOTxLOCxID.Loc = LOC.LOC
                           AND LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
                           /* Commented by CYOU - 13 Jul 2000 */
                           --                                                  AND LOC.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                           and  LOC.Locationflag <> "DAMAGE"
                           and  LOC.Locationflag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand

                           AND LOTxLOCxID.loc <> @c_currentloc
                           AND LOC.Facility = @c_zone01 -- make sure we pull from the RIGHT Facility
                           ORDER BY lottable04, lottable05, LOTxLOCxID.LOT
                        END
                        IF @@ROWCOUNT = 0
                        BEGIN
                           SET ROWCOUNT 0
                           IF @b_debug = 1
                           BEGIN
                              SELECT 'BREAK HERE'
                           END
                           BREAK
                        END
                        SET ROWCOUNT 0
                        IF @b_debug = 1
                        BEGIN
                           SELECT 'Lot after selection' , @c_fromlot
                        END
                     END
                  ELSE
                     BEGIN
                        SELECT @c_fromlot = @c_fromlot2
                     END -- IF @b_donecheckoverallocatedlots = 1
                     SET ROWCOUNT 0
                     SELECT @c_fromloc = SPACE(10)
                     WHILE (1=1 and @n_remainingqty > 0 and @n_numberofrecs < @n_limitrecs )
                     BEGIN
                        IF @c_zone02 = "ALL"
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromloc = LOTxLOCxID.LOC
                           FROM LOTxLOCxID (NOLOCK) , LOC (NOLOCK)
                           WHERE LOT = @c_fromlot
                           AND LOTxLOcxID.loc = LOC.loc
                           AND LOTxLOCxID.LOC > @c_fromloc
                           AND storerkey = @c_currentstorer
                           AND sku = @c_currentsku
                           AND LOTxLOCxID.Loc = LOC.LOC
                           and  LOC.Locationflag <> "DAMAGE"
                           and  LOC.Locationflag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                           AND LOTxLOCxID.loc <> @c_currentloc
                           ORDER BY LOTxLOCxID.LOC
                        END
                     ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromloc = LOTxLOCxID.LOC
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                           WHERE LOT = @c_fromlot
                           AND LOTxLOcxID.loc = LOC.loc
                           AND LOTxLOCxID.LOC > @c_fromloc
                           AND storerkey = @c_currentstorer
                           AND sku = @c_currentsku
                           AND LOTxLOCxID.Loc = LOC.LOC
                           /* Commented by CYOU - 13 Jul 2000 */
                           --                                                  AND LOC.putawayzone in ( @c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                           and  LOC.Locationflag <> "DAMAGE"
                           and  LOC.Locationflag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                           AND LOTxLOCxID.loc <> @c_currentloc
                           AND LOC.Facility = @c_zone01 -- make sure we pull from the RIGHT Facility
                           ORDER BY LOTxLOCxID.LOC
                        END
                        IF @@ROWCOUNT = 0
                        BEGIN
                           SET ROWCOUNT 0
                           BREAK
                        END
                        SET ROWCOUNT 0
                        SELECT @c_fromid = replicate(char(14),18)
                        WHILE (1=1 and @n_remainingqty > 0 and @n_numberofrecs < @n_limitrecs )
                        BEGIN
                           IF @c_zone02 = "ALL"
                           BEGIN
                              SET ROWCOUNT 1
                              SELECT @c_fromid = ID,
                              @n_onhandqty = LOTxLOCxID.QTY - QTYPICKED - QTYALLOCATED
                              FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                              WHERE LOT = @c_fromlot
                              AND LOTxLOcxID.loc = LOC.loc
                              AND LOTxLOCxID.LOC = @c_fromloc
                              AND id > @c_fromid
                              AND storerkey = @c_currentstorer
                              AND sku = @c_currentsku
                              and  LOC.Locationflag <> "DAMAGE"
                              and  LOC.Locationflag <> "HOLD"
                              AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                              AND LOTxLOCxID.loc <> @c_currentloc
                              ORDER BY ID
                           END
                        ELSE
                           BEGIN
                              SET ROWCOUNT 1
                              SELECT @c_fromid = ID,
                              @n_onhandqty = LOTxLOCxID.QTY - QTYPICKED - QTYALLOCATED
                              FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                              WHERE LOT = @c_fromlot
                              AND LOTxLOcxID.loc = LOC.loc
                              AND LOTxLOCxID.LOC = @c_fromloc
                              AND id > @c_fromid
                              AND storerkey = @c_currentstorer
                              AND sku = @c_currentsku
                              /* Commented by CYOU - 13 Jul 2000 */
                              --                                                       AND LOC.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                              and  LOC.Locationflag <> "DAMAGE"
                              and  LOC.Locationflag <> "HOLD"
                              AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                              AND LOTxLOCxID.loc <> @c_currentloc
                              AND LOC.Facility = @c_zone01 -- make sure we pull from the RIGHT Facility
                              ORDER BY ID
                           END
                           IF @@ROWCOUNT = 0
                           BEGIN
                              SET ROWCOUNT 0
                              BREAK
                           END
                           SET ROWCOUNT 0
                           /* We have a candidate FROM record */
                           /* Verify that the candidate ID is not on HOLD */
                           /* We could have done this in the SQL statements above */
                           /* But that would have meant a 5-way join.             */
                           /* SQL SERVER seems to work best on a maximum of a     */
                           /* 4-way join.                                     */
                           IF EXISTS(SELECT * FROM ID (NOLOCK) WHERE ID = @c_fromid
                           and STATUS = "HOLD")
                           BEGIN
                              BREAK -- Get out of loop, so that next candidate can be evaluated
                           END
                           /* Verify that the from location is not overallocated in skuxloc */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                           WHERE STORERKEY = @c_currentstorer
                           AND SKU = @c_currentsku
                           AND LOC = @c_fromloc
                           AND QTYEXPECTED > 0
                           )
                           BEGIN
                              BREAK -- Get out of loop, so that next candidate can be evaluated
                           END
                           /* Verify that the FROM location is not the */
                           /* PIECE PICK location for this product.    */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                           WHERE STORERKEY = @c_currentstorer
                           AND SKU = @c_currentsku
                           AND LOC = @c_fromloc
                           AND LOCATIONTYPE = "PICK"
                           )
                           BEGIN
                              BREAK -- Get out of loop, so that next candidate can be evaluated
                           END
                           /* Verify that the FROM location is not the */
                           /* CASE PICK location for this product.     */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                           WHERE STORERKEY = @c_currentstorer
                           AND SKU = @c_currentsku
                           AND LOC = @c_fromloc
                           AND LOCATIONTYPE = "CASE"
                           )
                           BEGIN
                              BREAK -- Get out of loop, so that next candidate can be evaluated
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
                           IF @n_skulocavailableqty < @n_onhandqty
                           BEGIN
                              SELECT @n_onhandqty = @n_skulocavailableqty
                           END
                           /* How many cases can I get from this record? */
                           SELECT @n_possiblecases = floor(@n_onhandqty / @n_currentfullcase)
                           /* How many do we take? */
                           IF @n_possiblecases > @n_remainingcases
                           BEGIN
                              SELECT @n_fromqty = @n_remainingcases * @n_currentfullcase,
                              @n_remainingqty = @n_remainingqty - (@n_remainingcases * @n_currentfullcase),
                              @n_remainingcases = 0
                           END
                        ELSE
                           BEGIN
                              SELECT @n_fromqty = @n_possiblecases * @n_currentfullcase,
                              @n_remainingqty = @n_remainingqty - (@n_possiblecases * @n_currentfullcase),
                              @n_remainingcases =  @n_remainingcases - @n_possiblecases
                           END
                           IF @n_fromqty > 0
                           BEGIN
                              EXECUTE nspg_GetKey
                              @keyname       = "REPLENISHKEY",
                              @fieldlength   = 10,
                              @keystring     = @c_ReplenishmentKey OUTPUT,
                              @b_Success     = @b_success   OUTPUT,
                              @n_err         = @n_err       OUTPUT,
                              @c_errmsg      = @c_errmsg    OUTPUT
                              IF NOT @b_success = 1
                              BEGIN
                                 SELECT @n_continue = 3
                                 BREAK
                              END
                              IF @n_continue = 1 or @n_continue = 2
                              BEGIN
                                 --																	  IF (SELECT Replenishmentcasecnt FROM SKUXLOC (NOLOCK)
                                 --																	  		 WHERE Storerkey = @c_currentstorer
                                 --																			   AND SKU = @c_currentsku
                                 --																				AND LOC = @c_currentloc) > 1
                                 --																	  BEGIN
                                 --																	  		SELECT @c_uom = PACKUOM1 FROM PACK (NOLOCK), SKU (NOLOCK)
                                 --																			 WHERE SKU.PACKKEY = PACK.PACKKEY
                                 --																			 	AND SKU.Storerkey = @c_currentstorer
                                 --																				AND SKU.SKU = @c_currentsku
                                 --																	  END
                                 --																	  ELSE
                                 --																	  BEGIN
                                 SELECT @c_uom = PACKUOM3 FROM PACK (NOLOCK), SKU (NOLOCK)
                                 WHERE SKU.PACKKEY = PACK.PACKKEY
                                 AND SKU.Storerkey = @c_currentstorer
                                 AND SKU.SKU = @c_currentsku
                                 --																	  END
                              END
                              IF @n_continue = 1 or @n_continue = 2
                              BEGIN
                                 INSERT REPLENISHMENT (
                                 ReplenishmentGroup,
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
                                 Priority)
                                 VALUES (
                                 @c_taskid,
                                 @c_ReplenishmentKey,
                                 @c_currentStorer,
                                 @c_currentSku,
                                 @c_fromLoc,
                                 @c_currentLoc,
                                 @c_fromlot,
                                 @c_fromid,
                                 @n_fromqty,
                                 @c_uom,
                                 "",
                                 @c_currentpriority)
                              END
                              SELECT @n_numberofrecs = @n_numberofrecs + 1
                           END
                           /*
                           select @c_currentsku, @c_currentloc, @c_currentpriority, @n_currentfullcase, @n_currentseverity
                           select "@n_fromqty ", @n_fromqty, "fromloc", @c_fromloc, "fromlot",@c_fromlot, "Possiblecases", @n_possiblecases
                           */
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
   /*
   select * from replenishment where replenishmentgroup = @c_taskid
   */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      /* Update the column QtyInPickLoc in the Replenishment Table */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         UPDATE REPLENISHMENT SET QtyInPickLoc = SkuxLoc.Qty - SkuxLoc.QtyPicked
         FROM SKUxLOC
         WHERE REPLENISHMENT.Storerkey = Skuxloc.Storerkey AND
         REPLENISHMENT.SKu = Skuxloc.Sku AND
         REPLENISHMENT.toloc = SkuxLoc.loc AND
         REPLENISHMENT.ReplenishmentGroup = @c_taskid
         /* UPDATE REPLENISHMENT SET QtyInPickLoc = 0      */
         /*     WHERE ( QtyInPickLoc < 0 or                */
         /*           QtyInPickLoc  Is Null )              */
         /*           And ReplenishmentGroup = @c_taskid   */
      END
      /* End Update the column QtyInPickLoc in the Replenishment Table */
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         EXEC ("DECLARE CURSOR_REPLENISHMENT_TASKS SCROLL CURSOR FOR
         SELECT    ReplenishmentGroup,
         ReplenishmentKey,
         StorerKey,
         Sku,
         FromLoc,
         ToLoc,
         Lot,
         Id,
         Qty,
         QtyMoved,
         UOM,
         PackKey,
         QtyInPickLoc
         FROM REPLENISHMENT
         WHERE ReplenishmentGroup = N'" + @c_taskid + "'
         AND QTY-QTYMoved > 0
         ORDER BY Priority
         FOR UPDATE OF QtyMoved"
         )
         OPEN CURSOR_REPLENISHMENT_TASKS
         /* Close and deallocate cursor, returning error message if the */
         /* Cursor does not have any rows */
         IF ABS(@@CURSOR_ROWS) = 0
         BEGIN
            SELECT @n_continue = 3
            CLOSE CURSOR_REPLENISHMENT_TASKS
            DEALLOCATE CURSOR_REPLENISHMENT_TASKS
            SELECT @n_err = 65201
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Nothing To Do! (nspRFRP01)"
         END
      ELSE
         BEGIN
            SELECT @n_returnrecs = @@CURSOR_ROWS
         END
      END
   END
   /* Set RF Return Record */
   IF @n_continue=3
   BEGIN
      IF @c_retrec="01"
      BEGIN
         SELECT @c_retrec="09"
      END
   END
ELSE
   BEGIN
      SELECT @c_retrec="01"
   END
   /* End Set RF Return Record */
   /* Construct RF Return String */
   SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
   + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
   + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
   + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
   + dbo.fnc_RTrim(@c_errmsg)    + @c_senddelimiter
   + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(10),@n_returnrecs)))
   SELECT dbo.fnc_RTrim(@c_outstring)
   /* End Construct RF Return String */
   /* End Main Processing */
   /* Post Process Starts */
   /* #INCLUDE <SPRFRP01_2.SQL> */
   /* Post Process Ends */
   /* Return Statement */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFRP01"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
ELSE
   BEGIN
      /* Error Did Not Occur , Return Normally */
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   /* End Return Statement */
END

GO