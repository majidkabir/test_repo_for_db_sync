SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMEvaluateRPTasks                              */
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
/*2017-11-30    JHTAN         INC0057738 - Deploy SP exception err(JH01)*/
/************************************************************************/

CREATE PROC    [dbo].[nspTTMEvaluateRPTasks]
 @c_sendDelimiter    NVARCHAR(1)
 ,              @c_ptcid            NVARCHAR(10)
 ,              @c_userid           NVARCHAR(18)
 ,              @c_strategykey      NVARCHAR(10)
 ,              @c_ttmstrategykey   NVARCHAR(10)
 ,              @c_ttmpickcode      NVARCHAR(10)
 ,              @c_ttmoverride      NVARCHAR(10)
 ,              @c_areakey01        NVARCHAR(10)
 ,              @c_areakey02        NVARCHAR(10)
 ,              @c_areakey03        NVARCHAR(10)
 ,              @c_areakey04        NVARCHAR(10)
 ,              @c_areakey05        NVARCHAR(10)
 ,              @c_lastloc          NVARCHAR(10)
 ,              @c_outstring        NVARCHAR(255)  OUTPUT
 ,              @b_Success          int        OUTPUT
 ,              @n_err              int        OUTPUT
 ,              @c_errmsg           NVARCHAR(250)  OUTPUT
 ,              @c_fromloc          NVARCHAR(10) OUTPUT  --(JH01)
 ,              @c_TaskDetailKey    NVARCHAR(10) OUTPUT  --(JH01)
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE @b_debug int
 SELECT @b_debug = 0
 DECLARE        @n_continue int        ,  
 @n_starttcnt int        , -- Holds the current transaction count
 @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
 @n_err2 int               -- For Additional Error Detection
 DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
 DECLARE @n_cqty int, @n_returnrecs int
 SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
 SELECT @c_retrec = "01"
 SELECT @n_returnrecs=1
 DECLARE @c_executestmt NVARCHAR(255), @c_AlertMessage NVARCHAR(255), @b_gotarow int
 --DECLARE @b_cursor_open int, @c_taskdetailkey NVARCHAR(10), @c_replenishmentgroup NVARCHAR(10)  --(JH01)
 DECLARE @b_cursor_open int, @c_replenishmentgroup NVARCHAR(10)  --(JH01)
 DECLARE @c_storerkey NVARCHAR(15), @c_sku NVARCHAR(20),
 @c_droploc NVARCHAR(10), @c_dropid NVARCHAR(18), @c_lot NVARCHAR(10), @c_packkey NVARCHAR(10), @c_uom NVARCHAR(5),
 @c_caseid NVARCHAR(10),
 @b_skipthetask int
 SELECT @b_gotarow = 0
      /* #INCLUDE <SPEVRP_1.SQL> */     
 IF @n_continue=1 OR @n_continue=2
 BEGIN
    EXECUTE nspg_GetKey
    @keyname       = "REPLENISHGROUP",
    @fieldlength   = 10,
    @keystring     = @c_replenishmentgroup    OUTPUT,
    @b_success     = @b_success   OUTPUT,
    @n_err         = @n_err       OUTPUT,
    @c_errmsg      = @c_errmsg    OUTPUT
    IF NOT @b_success = 1
    BEGIN
       SELECT @n_continue = 3
    END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    DELETE FROM REPLENISHMENT_LOCK
    WHERE PTCID = @c_ptcid or
    datediff(second,adddate,getdate()) > 900  -- 15 minutes
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    DECLARE @c_currentsku NVARCHAR(20), @c_currentstorer NVARCHAR(15),
    @c_currentloc NVARCHAR(10), @c_currentpriority NVARCHAR(5),
    @n_currentfullcase int, @n_currentseverity int,
    --@c_fromloc NVARCHAR(10), --(JH01)
    @c_fromlot NVARCHAR(10), @c_fromid NVARCHAR(18),
    @n_fromqty int, @n_remainingqty int, @n_possiblecases int ,
    @n_remainingcases int, @n_onhandqty int, @n_fromcases int ,
    @c_ReplenishmentKey NVARCHAR(10), @n_numberofrecs int, @n_limitrecs int,
    @n_junkcount int, @c_fromlot2 NVARCHAR(10),
    @b_donecheckoverallocatedlots int,
    @n_skulocavailablecapacity int,
    @n_skulocavailableqty int
    SELECT @c_currentsku = SPACE(20), @c_currentstorer = SPACE(15),
    @c_currentloc = SPACE(10), @c_currentpriority = SPACE(5),
    @n_currentfullcase = 0   , @n_currentseverity = 9999999 ,
    @n_fromqty = 0, @n_remainingqty = 0, @n_possiblecases = 0,
    @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,
    @n_limitrecs = 1 -- @n_limitrecs should always be 1 for the task manager version of replenishment
    SELECT replenishmentpriority, replenishmentseverity ,storerkey,
    sku, loc, replenishmentcasecnt
    INTO #tempskuxloc
    FROM SKUxLOC (NOLOCK) 
    WHERE 1=2
    IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NULL
    BEGIN
       INSERT #tempskuxloc
       SELECT replenishmentpriority, replenishmentseverity ,storerkey,
       sku, loc.loc, replenishmentcasecnt
       FROM SKUxLOC (NOLOCK)  ,TaskManagerUserDetail (NOLOCK),AreaDetail (NOLOCK),Loc (NOLOCK)
WHERE  (skuxloc.locationtype = "PICK" or skuxloc.locationtype = "CASE")
       and  replenishmentseverity > 0
       and  skuxloc.qty - skuxloc.qtypicked < skuxloc.qtylocationlimit
       and TaskManagerUserDetail.UserKey = @c_userid
       and TaskManagerUserDetail.PermissionType = "RP"
       and TaskManagerUserDetail.Permission = "1"
       and TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
       and AreaDetail.Putawayzone = Loc.PutAwayZone
       and skuxloc.loc = Loc.loc
    END
    ELSE
    BEGIN
       INSERT #tempskuxloc
       SELECT replenishmentpriority, replenishmentseverity ,storerkey,
       sku, loc.loc, replenishmentcasecnt
       FROM SKUxLOC (NOLOCK)  , LOC (NOLOCK), AREADETAIL (NOLOCK)
       WHERE SKUxLOC.LOC = LOC.LOC
       and  LOC.Locationflag <> "DAMAGE"
       and  LOC.Locationflag <> "HOLD"
       and  LOC.Status <> "HOLD"
       and  (skuxloc.locationtype = "PICK" or skuxloc.locationtype = "CASE")
       and  replenishmentseverity > 0
       and  skuxloc.qty - skuxloc.qtypicked < skuxloc.qtylocationlimit
       and AreaDetail.AreaKey = @c_areakey01
       and AreaDetail.Putawayzone = Loc.PutAwayZone
       and skuxloc.loc = Loc.loc
    END
    WHILE (1=1 and @n_numberofrecs < @n_limitrecs )
    BEGIN
       SET ROWCOUNT 1
       SELECT @c_currentpriority = replenishmentpriority
       FROM #tempskuxloc
       WHERE replenishmentpriority > @c_currentpriority
       and  replenishmentcasecnt > 0
       ORDER BY replenishmentpriority
       IF @@ROWCOUNT = 0
       BEGIN
          SET ROWCOUNT 0
          BREAK
       END
       SET ROWCOUNT 0
       SELECT @n_currentseverity = 999999999
       WHILE (1=1 and @n_numberofrecs < @n_limitrecs )
       BEGIN
          SET ROWCOUNT 1
          SELECT @n_currentseverity = replenishmentseverity
          FROM #tempskuxloc
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
          SELECT @c_currentsku = SPACE(20), @c_currentstorer = SPACE(15),
          @c_currentloc = SPACE(10)
          WHILE (1=1 and @n_numberofrecs < @n_limitrecs )
          BEGIN
             SET ROWCOUNT 1
             SELECT @c_currentstorer = storerkey
             FROM #tempskuxloc
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
             SELECT @c_currentsku = SPACE(20),
             @c_currentloc = SPACE(10)
             WHILE (1=1 and @n_numberofrecs < @n_limitrecs )
             BEGIN
                SET ROWCOUNT 1
                SELECT @c_currentstorer = storerkey ,
                @c_currentsku = sku,
                @c_currentloc = loc,
                @n_currentfullcase = replenishmentcasecnt
                FROM #tempskuxloc
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
                SELECT @c_fromloc = SPACE(10),  @c_fromlot = SPACE(10), @c_fromid = SPACE(18),
                @c_fromlot2 = SPACE(10),
                @n_fromqty = 0, @n_possiblecases = 0,
                @n_remainingqty = @n_currentseverity * @n_currentfullcase,
          @n_remainingcases = @n_currentseverity,
                @b_donecheckoverallocatedlots = 0
                WHILE (1=1 and @n_remainingqty > 0 and @n_numberofrecs < @n_limitrecs )
                BEGIN
                   IF @b_donecheckoverallocatedlots = 0 -- That means that the last try at this section of code was successful therefore try again.
                   BEGIN
                      IF @b_debug = 1
                      BEGIN
                         SELECT "Checking To See if Lots are overallocated..."
                      END
                      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NULL
                      BEGIN
                         SET ROWCOUNT 1
                         SELECT @c_fromlot2 = LOT
                         FROM LOTxLOCxID (NOLOCK)  , LOC (NOLOCK) 
                         WHERE LOT > @c_fromlot2
                         AND storerkey = @c_currentstorer
                         AND sku = @c_currentsku
                         AND LOTxLOCxID.LOC = LOC.LOC
                         AND LOTxLOCxID.qtyexpected > 0
                         AND LOTxLOCxID.loc = @c_currentloc
                         ORDER BY LOTxLOCxID.LOT
                      END
                      ELSE
                      BEGIN
                         SET ROWCOUNT 1
                         SELECT @c_fromlot2 = LOT
                         FROM LOTxLOCxID (NOLOCK) , LOC (NOLOCK) 
                         WHERE LOT > @c_fromlot2
                         AND storerkey = @c_currentstorer
                         AND sku = @c_currentsku
                         AND LOTxLOCxID.Loc = LOC.LOC
                         AND LOTxLOCxID.qtyexpected > 0
                         AND LOTxLOCxID.loc = @c_currentloc
                         ORDER BY LOTxLOCxID.LOT
                      END
                      IF @@ROWCOUNT = 0
                      BEGIN
                         SELECT @b_donecheckoverallocatedlots = 1
                         SELECT @c_fromlot = ""
                      END
                   END --IF @b_donecheckoverallocatedlots = 0
                   SET ROWCOUNT 0
                   IF @b_debug = 1
                   BEGIN
                      SELECT "@c_fromlot2 is ",@c_fromlot2
                   END
                   IF @b_donecheckoverallocatedlots = 1
                   BEGIN
                      IF @b_debug = 1
                      BEGIN
                         SELECT "Not lots overallocated, checking to see if there are any locations that we can pull lots from..."
                      END
                      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NULL
                      BEGIN
                         SET ROWCOUNT 1
                         SELECT @c_fromlot = LOT
                         FROM LOTxLOCxID (NOLOCK)  , LOC (NOLOCK) ,TaskManagerUserDetail (NOLOCK) ,AreaDetail (NOLOCK) 
                         WHERE LOT > @c_fromlot
                         AND storerkey = @c_currentstorer
                         AND sku = @c_currentsku
                         AND LOTxLOCxID.Loc = LOC.LOC
                         and  LOC.Locationflag <> "DAMAGE"
                         and  LOC.Locationflag <> "HOLD"
                         and  LOC.Status <> "HOLD"
                         AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                         AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                         AND LOTxLOCxID.loc <> @c_currentloc
                         AND TaskManagerUserDetail.UserKey = @c_userid
                         AND TaskManagerUserDetail.PermissionType = "RP"
                         AND TaskManagerUserDetail.Permission = "1"
                         AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
                         AND AreaDetail.Putawayzone = Loc.PutAwayZone
                         ORDER BY LOT
                      END
                      ELSE
                      BEGIN
                         SET ROWCOUNT 1
                         SELECT @c_fromlot = LOT
                         FROM LOTxLOCxID (NOLOCK)  , LOC,AreaDetail (NOLOCK) 
                        WHERE LOT > @c_fromlot
                         AND storerkey = @c_currentstorer
                         AND sku = @c_currentsku
                         AND LOTxLOCxID.Loc = LOC.LOC
                         and  LOC.Locationflag <> "DAMAGE"
                         and  LOC.Locationflag <> "HOLD"
                         and  LOC.Status <> "HOLD"
                         AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                         AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                         AND LOTxLOCxID.loc <> @c_currentloc
                         AND AreaDetail.AreaKey = @c_areakey01
                         AND AreaDetail.Putawayzone = Loc.PutAwayZone
                         ORDER BY LOT
                      END
                      IF @@ROWCOUNT = 0
                      BEGIN
                         SET ROWCOUNT 0
                         BREAK
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
                      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NULL
                      BEGIN
                         SET ROWCOUNT 1
                         SELECT @c_fromloc = LOTxLOCxID.LOC
                         FROM LOTxLOCxID (NOLOCK) ,LOC (NOLOCK) ,TaskManagerUserDetail (NOLOCK) ,AreaDetail (NOLOCK) 
                         WHERE LOT = @c_fromlot
                         AND LOTxLOcxID.loc = LOC.loc
                         AND LOTxLOCxID.LOC > @c_fromloc
                         AND storerkey = @c_currentstorer
                         AND sku = @c_currentsku
                         AND LOTxLOCxID.Loc = LOC.LOC
                         and  LOC.Locationflag <> "DAMAGE"
                         and  LOC.Locationflag <> "HOLD"
                         and  LOC.Status <> "HOLD"
                         AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                         AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                         AND LOTxLOCxID.loc <> @c_currentloc
                         AND TaskManagerUserDetail.UserKey = @c_userid
                         AND TaskManagerUserDetail.PermissionType = "RP"
                         AND TaskManagerUserDetail.Permission = "1"
                         AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
                         AND AreaDetail.Putawayzone = Loc.PutAwayZone
                         ORDER BY LOTxLOCxID.LOC
                      END
                      ELSE
                      BEGIN
                         SET ROWCOUNT 1
                         SELECT @c_fromloc = LOTxLOCxID.LOC
                         FROM LOTxLOCxID (NOLOCK)  , LOC (NOLOCK) ,AreaDetail (NOLOCK) 
                         WHERE LOT = @c_fromlot
                         AND LOTxLOcxID.loc = LOC.loc
                         AND LOTxLOCxID.LOC > @c_fromloc
                         AND storerkey = @c_currentstorer
                         AND sku = @c_currentsku
                         AND LOTxLOCxID.Loc = LOC.LOC
                         and  LOC.Locationflag <> "DAMAGE"
                         and  LOC.Locationflag <> "HOLD"
                         and  LOC.Status <> "HOLD"
                         AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                         AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                         AND LOTxLOCxID.loc <> @c_currentloc
                         AND AreaDetail.AreaKey = @c_areakey01
                         AND AreaDetail.Putawayzone = Loc.PutAwayZone
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
                         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NULL
                         BEGIN
                            SET ROWCOUNT 1
                            SELECT @c_fromid = ID,
                            @n_onhandqty = LOTxLOCxID.QTY - QTYPICKED - QTYALLOCATED
                            FROM LOTxLOCxID (NOLOCK) , LOC (NOLOCK) ,TaskManagerUserDetail (NOLOCK) ,AreaDetail (NOLOCK) 
                            WHERE LOT = @c_fromlot
                            AND LOTxLOcxID.loc = LOC.loc
                            AND LOTxLOCxID.LOC = @c_fromloc
                            AND id > @c_fromid
                            AND storerkey = @c_currentstorer
                            AND sku = @c_currentsku
                            and  LOC.Locationflag <> "DAMAGE"
                            and  LOC.Locationflag <> "HOLD"
                            and  LOC.Status <> "HOLD"
                            AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                            AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                            AND LOTxLOCxID.loc <> @c_currentloc
                            AND TaskManagerUserDetail.UserKey = @c_userid
                            AND TaskManagerUserDetail.PermissionType = "RP"
                            AND TaskManagerUserDetail.Permission = "1"
                            AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
                            AND AreaDetail.Putawayzone = Loc.PutAwayZone
                            ORDER BY ID
                         END
                         ELSE
                         BEGIN
                            SET ROWCOUNT 1
                            SELECT @c_fromid = ID,
                            @n_onhandqty = LOTxLOCxID.QTY - QTYPICKED - QTYALLOCATED
                            FROM LOTxLOCxID (NOLOCK) , LOC (NOLOCK) ,AreaDetail (NOLOCK) 
                            WHERE LOT = @c_fromlot
                            AND LOTxLOcxID.loc = LOC.loc
                            AND LOTxLOCxID.LOC = @c_fromloc
                            AND id > @c_fromid
                            AND storerkey = @c_currentstorer
                            AND sku = @c_currentsku
                            and  LOC.Locationflag <> "DAMAGE"
                            and  LOC.Locationflag <> "HOLD"
                            and  LOC.Status <> "HOLD"
                            AND LOTxLOCxID.qty - qtypicked - qtyallocated > 0
                            AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demand
                            AND LOTxLOCxID.loc <> @c_currentloc
                            AND AreaDetail.AreaKey = @c_areakey01
                            AND AreaDetail.Putawayzone = Loc.PutAwayZone
                            ORDER BY ID
                         END
                         IF @@ROWCOUNT = 0
                       BEGIN
                            SET ROWCOUNT 0
                            BREAK
                         END
                         SET ROWCOUNT 0
                         IF EXISTS(SELECT * FROM ID (NOLOCK)  WHERE ID = @c_fromid
                         and STATUS = "HOLD")
                         BEGIN
                            BREAK -- Get out of loop, so that next candidate can be evaluated
                         END
                         SELECT @b_success = 0, @b_skipthetask = 0
                         EXECUTE nspCheckSkipTasks
                         @c_userid
                         , ""
                         , "RP"
                         , ""
                         , @c_fromlot
                         , @c_fromloc
                         , @c_fromid
                         , @c_currentloc
                         , @c_fromid
                         , @b_skipthetask OUTPUT
                         , @b_Success OUTPUT
                         , @n_err OUTPUT
                         , @c_errmsg OUTPUT
                         IF @b_success <> 1
                         BEGIN
                            SELECT @n_continue=3
                         END
                         IF @b_skipthetask = 1
                         BEGIN
                            BREAK
                         END
                         IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK) 
                         WHERE STORERKEY = @c_currentstorer
                         AND SKU = @c_currentsku
                         AND LOC = @c_fromloc
                         AND QTYEXPECTED > 0
                            )
                         BEGIN
                            BREAK -- Get out of loop, so that next candidate can be evaluated
                         END
                         IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK) 
                         WHERE STORERKEY = @c_currentstorer
                         AND SKU = @c_currentsku
                         AND LOC = @c_fromloc
                         AND LOCATIONTYPE = "PICK"
                         )
                         BEGIN
                            BREAK -- Get out of loop, so that next candidate can be evaluated
                         END
                         IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK) 
                         WHERE STORERKEY = @c_currentstorer
                         AND SKU = @c_currentsku
                         AND LOC = @c_fromloc
                         AND LOCATIONTYPE = "CASE"
                         )
                         BEGIN
                            BREAK -- Get out of loop, so that next candidate can be evaluated
                         END
                         SELECT @n_skulocavailableqty = QTY - QTYALLOCATED - QTYPICKED
                         FROM SKUxLOC (NOLOCK) 
                         WHERE STORERKEY = @c_currentstorer
                         AND SKU = @c_currentsku
                         AND LOC = @c_fromloc
                         IF @n_skulocavailableqty < @n_onhandqty
                         BEGIN
                            SELECT @n_onhandqty = @n_skulocavailableqty
                         END
                         SELECT @n_possiblecases = floor(@n_onhandqty / @n_currentfullcase)
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
                         IF @n_fromqty <= 0   
                         BEGIN
                            BREAK -- Get out of loop, so that next candidate can be evaluated
                         END
                         IF @n_fromqty > 0
                         BEGIN
                            SELECT @n_skulocavailablecapacity = 0
                      SELECT @n_skulocavailablecapacity = FLOOR( (SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked))/SKUXLOC.ReplenishmentCaseCnt)
                            FROM SKUxLOC (NOLOCK) 
                            WHERE SKU = @c_currentsku AND
                            LOC = @c_currentloc
                            IF @n_skulocavailablecapacity <= 0
                            BEGIN
                               BREAK -- Get out of the current loop!
                            END
                            SELECT @b_success = 0
                            execute    nspCheckEquipmentProfile
                            @c_userid       =@c_userid
                            ,              @c_taskdetailkey=""
                            ,              @c_storerkey    =@c_currentstorer
                            ,              @c_sku          =@c_currentsku
                            ,              @c_lot          =@c_fromlot
                            ,              @c_fromLoc      =@c_fromloc
                            ,              @c_fromID       =@c_fromid
                            ,              @c_toLoc        =@c_currentloc
                            ,              @c_toID         =@c_fromid
                            ,              @n_qty          =0
                            ,              @b_Success      =@b_success    OUTPUT
                            ,              @n_err          =@n_err        OUTPUT
                            ,              @c_errmsg       =@c_errmsg     OUTPUT
                            IF @b_success = 0
                            BEGIN
                               BREAK
                            END
                            SELECT @n_junkcount = COUNT(*) FROM REPLENISHMENT_LOCK (NOLOCK) 
                            WHERE LOT = @c_fromlot AND
                            FROMLOC = @c_fromloc AND
                            TOLOC = @c_currentloc AND
                            ID = @c_fromid
                            IF @n_junkcount > 0
                            BEGIN
                               BREAK -- Get out of the current loop
                            END
                            IF @n_continue = 1 OR @n_continue = 2
                            BEGIN
                               INSERT REPLENISHMENT_LOCK (ptcid,storerkey,sku,fromloc,toloc,lot,id)
                               values (@c_ptcid,@c_currentstorer, @c_currentsku,@c_fromloc,@c_currentloc,@c_fromlot,@c_fromid)
                               SELECT @n_err = @@ERROR
                               IF NOT @n_err = 0
                               BEGIN
                                  SELECT @n_continue = 3
                                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into REPLENISHMENT_LOCK failed. (nspTTMEvaluateRPTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                               END
                            END
                            IF @n_continue = 1 or @n_continue = 2
                            BEGIN
                               EXECUTE nspg_GetKey
                               @keyname       = "REPLENISHKEY",
                               @fieldlength   = 9,
                               @keystring     = @c_TaskDetailKey OUTPUT,
                               @b_Success     = @b_success   OUTPUT,
                               @n_err         = @n_err       OUTPUT,
                               @c_errmsg      = @c_errmsg    OUTPUT
                               IF NOT @b_success = 1
                               BEGIN
                                  SELECT @n_continue = 3
                                  BREAK
                               END
                               SELECT @c_taskdetailkey = "R"+@c_taskdetailkey -- Place an "R" in front of the key so that it doesn't conflict with any TaskDetailKeys.
                            END
                            IF @n_continue = 1 OR @n_continue = 2
                            BEGIN
                               SELECT @c_packkey = sku.packkey,
                               @c_uom= pack.packuom3
                               FROM SKU (NOLOCK) ,PACK (NOLOCK) 
                               WHERE STORERKEY = @c_currentstorer
                               AND   SKU = @c_currentsku
                               AND   SKU.PACKKEY = PACK.PACKKEY
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
                               @c_taskdetailkey,
                               @c_taskdetailKey,
                               @c_currentStorer,
                               @c_currentSku,
                               @c_fromLoc,
                               @c_currentLoc,
                               @c_fromlot,
                               @c_fromid,
                               @n_fromqty,
                               @c_uom,
                               @c_packkey,
                               @c_currentpriority)
                            END
                            IF @n_continue = 1 or @n_continue = 2
                            BEGIN
                               SELECT @n_numberofrecs = @n_numberofrecs + 1
                               SELECT @b_gotarow = 1
                            END
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
 IF (@n_continue = 1 or @n_continue = 2) and @b_gotarow = 1
 BEGIN
    SELECT @c_outstring =
    @c_taskdetailkey          + @c_senddelimiter
    + dbo.fnc_RTrim(@c_currentstorer)         + @c_senddelimiter
    + dbo.fnc_RTrim(@c_currentsku)            + @c_senddelimiter
    + dbo.fnc_RTrim(@c_fromloc)               + @c_senddelimiter
    + dbo.fnc_RTrim(@c_fromid)                + @c_senddelimiter
    + dbo.fnc_RTrim(@c_currentloc)            + @c_senddelimiter
    + dbo.fnc_RTrim(@c_fromid)                + @c_senddelimiter
    + dbo.fnc_RTrim(@c_fromlot)               + @c_senddelimiter
    + dbo.fnc_RTrim(CONVERT(char(10),@n_fromqty)) + @c_senddelimiter
    + dbo.fnc_RTrim(@c_packkey)               + @c_senddelimiter
    + dbo.fnc_RTrim(@c_uom)                   + @c_senddelimiter
    + ""                              + @c_senddelimiter
    + ""                              + @c_senddelimiter
    + ""
 END
 ELSE
 BEGIN
    SELECT @c_outstring = ""
 END
 IF @b_debug = 1
 BEGIN
    SELECT @c_outstring
 END
      /* #INCLUDE <SPEVRP_2.SQL> */
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
    execute nsp_logerror @n_err, @c_errmsg, "nspTTMEvaluateRPTasks"
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
    RETURN
 END
 END

GO