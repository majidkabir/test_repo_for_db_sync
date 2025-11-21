SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_ReplenishmentRpt_BatchRefill_13                */
/* Creation Date: 08-Mar-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:  ECCO China Wave Replenishment Report (SOS#237417)          */
/*           Modified from nsp_ReplenishmentRpt_BatchRefill_07          */
/*                                                                      */
/*                                                                      */
/* Input Parameters: @c_Zone1 - facility                                */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: r_replenishment_report13                                  */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */ 
/* 05-MAR-2018 Wan01    1.1   WM - Add Functype                         */ 
/* 05-OCT-2018 CZTENG01 1.2   WM - Add ReplGrp                          */      
/************************************************************************/

CREATE PROC  [dbo].[isp_ReplenishmentRpt_BatchRefill_13]
               @c_zone01      NVARCHAR(20)
,              @c_zone02      NVARCHAR(20)
,              @c_zone03      NVARCHAR(20)
,              @c_zone04      NVARCHAR(20)
,              @c_zone05      NVARCHAR(20)
,              @c_zone06      NVARCHAR(20)
,              @c_zone07      NVARCHAR(20)
,              @c_zone08      NVARCHAR(20)
,              @c_zone09      NVARCHAR(20)-- SOS #89979 START SKU
,              @c_zone10      NVARCHAR(20)-- SOS #89979 END SKU
,              @c_zone11      NVARCHAR(20)-- SOS #89979 START AILSE
,              @c_zone12      NVARCHAR(20)-- SOS #89979 END AILSE
,              @c_storerkey   NVARCHAR(15) = 'ALL'
,              @c_ReplGrp     NVARCHAR(30) = 'ALL' --(CZTENG01)
,              @c_Functype    NCHAR(1) = ''        --(Wan01)  
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_WARNINGS OFF          
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF          

   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   ,               @n_starttcnt   int

   DECLARE @b_debug int,
   @c_Packkey    NVARCHAR(10),
   @c_UOM        NVARCHAR(10), 
   @c_Zone08End  NVARCHAR(10), 
   @n_qtytaken   int
   SELECT @n_continue=1, @b_debug = 0

   IF @c_zone12 <> ''
      SELECT @b_debug = CAST( @c_zone12 AS int)

   -- Start : #89979
   IF @c_Zone08 = ''
      SET @c_Zone08End = 'ZZZZZZZZZZZZZZZZZZZZ'
   ELSE
      SET @c_Zone08End = @c_Zone08     

   IF @c_zone10 = ''
      SELECT @c_zone10 = 'ZZZZZZZZZZZZZZZZZZZZ'
   IF @c_zone12 = ''
      SELECT @c_zone12 = 'ZZZZZZZZZZZZZZZZZZZZ'
   -- End : #89979

   DECLARE @c_priority  NVARCHAR(5)
   
   --(Wan01) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END

   IF @c_FuncType = 'P'                                     
   BEGIN 
      GOTO QUIT_SP
   END    
   --(Wan01) - END     

   SELECT StorerKey, 
            SKU, 
            LOC as FromLOC, 
            LOC as ToLOC, 
            Lot, 
            Id, 
            Qty, 
            Qty as QtyMoved, 
            Qty as QtyInPickLOC,
            @c_priority as Priority, 
            Lot as UOM, 
            Lot PackKey
   INTO #REPLENISHMENT
   FROM LOTxLOCxID WITH (NOLOCK)
   WHERE 1 = 2
   
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
      @n_SKULocAvailableQty int

      SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
      @c_CurrentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),
      @n_CurrentFullCase = 0   , @n_CurrentSeverity = 9999999 ,
      @n_FromQty = 0, @n_remainingqty = 0, @n_PossibleCases = 0,
      @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,
      @n_limitrecs = 5
      
      /* Make a temp version of SKUxLOC */
      SELECT ReplenishmentPriority, 
               ReplenishmentSeverity,StorerKey,
               SKU, LOC, ReplenishmentCasecnt
      INTO #TempSKUxLOC
      FROM SKUxLOC WITH (NOLOCK)
      WHERE 1=2
      
      IF (@c_zone02 = 'ALL')
      BEGIN
         INSERT #TempSKUxLOC
         SELECT DISTINCT SKUxLOC.ReplenishmentPriority,
         ReplenishmentSeverity =
               CASE WHEN PACK.CaseCnt > 0 
                  THEN FLOOR( ( CONVERT(real,QtyLocationLimit) - 
                                    ( CONVERT(real,SKUxLOC.Qty) - 
                                       CONVERT(real,SKUxLOC.QtyPicked) - 
                                       CONVERT(real,SKUxLOC.QtyAllocated) ) 
                                 ) / CONVERT(real,PACK.CaseCnt) )
                  ELSE QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))
               END,
         SKUxLOC.StorerKey,
         SKUxLOC.SKU,
         SKUxLOC.LOC,
         ReplenishmentCasecnt = 
            CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt
               ELSE 1
            END
         FROM SKUxLOC WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
         JOIN SKU WITH (NOLOCK) ON SKUxLOC.StorerKey = SKU.StorerKey AND  SKUxLOC.SKU = SKU.SKU
         JOIN PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PACKKey 
         JOIN (SELECT SKUxLOC.STORERKEY, SKUxLOC.SKU, SKUxLOC.LOC 
               FROM   SKUxLOC WITH (NOLOCK) 
               JOIN   LOC WITH (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
               WHERE  SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0 
               AND    SKUxLOC.LocationType NOT IN ('PICK','CASE') 
               AND    LOC.FACILITY = @c_Zone01 
               AND    LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') 
               --AND    SKUXLOC.Storerkey BETWEEN @c_zone08 AND @c_Zone08End  -- #89979
               AND    (SKUXLOC.Storerkey = @c_Storerkey OR @c_Storerkey='ALL')
               AND    SKUXLOC.SKU BETWEEN @c_zone09 AND @c_zone10 -- #89979
               ) AS SL 
               ON SL.STORERKEY = SKUxLOC.StorerKey AND SL.SKU = SKUxLOC.SKU 
         WHERE LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
         AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')
         AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
         AND  LOC.FACILITY = @c_Zone01
         --AND  SKUXLOC.Storerkey BETWEEN @c_zone08 AND @c_Zone08End  -- #89979
         AND (SKUXLOC.Storerkey = @c_Storerkey OR @c_Storerkey='ALL')
         AND  SKUXLOC.SKU BETWEEN @c_zone09 AND @c_zone10 -- #89979
         AND  LOC.LocAisle BETWEEN @c_zone11 AND @c_zone12 -- #89979
      END
      ELSE
      BEGIN
         INSERT #TempSKUxLOC
         SELECT DISTINCT SKUxLOC.ReplenishmentPriority,
         ReplenishmentSeverity =
               CASE WHEN PACK.CaseCnt > 0 
                  THEN FLOOR( ( CONVERT(real,QtyLocationLimit) - 
                                    ( CONVERT(real,SKUxLOC.Qty) - 
                                       CONVERT(real,SKUxLOC.QtyPicked) - 
                                       CONVERT(real,SKUxLOC.QtyAllocated) ) 
                                 ) / CONVERT(real,PACK.CaseCnt) )
                  ELSE QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))
               END,
         SKUxLOC.StorerKey,
         SKUxLOC.SKU,
         SKUxLOC.LOC,
         ReplenishmentCasecnt = 
            CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt
               ELSE 1
            END
         FROM SKUxLOC WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
         JOIN SKU WITH (NOLOCK) ON SKUxLOC.StorerKey = SKU.StorerKey AND  SKUxLOC.SKU = SKU.SKU
         JOIN PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PACKKey 
         JOIN (SELECT SKUxLOC.STORERKEY, SKUxLOC.SKU, SKUxLOC.LOC 
               FROM   SKUxLOC WITH (NOLOCK) 
               JOIN   LOC WITH (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
               WHERE  SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0
               AND    SKUxLOC.LocationType NOT IN ('PICK','CASE')
               AND    LOC.FACILITY = @c_Zone01 
               AND    LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
               --AND    SKUXLOC.Storerkey BETWEEN @c_zone08 AND @c_Zone08End  -- #89979
               AND (SKUXLOC.Storerkey = @c_Storerkey OR @c_Storerkey='ALL')
               AND    SKUXLOC.SKU BETWEEN @c_zone09 AND @c_zone10 -- #89979
               ) AS SL 
               ON SL.STORERKEY = SKUxLOC.StorerKey AND SL.SKU = SKUxLOC.SKU 
         WHERE LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
         AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')
         AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
         AND  LOC.FACILITY = @c_Zone01
         --AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12) -- #89979
         AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07) -- #89979
         --AND  SKUXLOC.Storerkey BETWEEN @c_zone08 AND @c_Zone08End  -- #89979
         AND (SKUXLOC.Storerkey = @c_Storerkey OR @c_Storerkey='ALL')
         AND  SKUXLOC.SKU BETWEEN @c_zone09 AND @c_zone10 -- #89979
         AND  LOC.LocAisle BETWEEN @c_zone11 AND @c_zone12 -- #89979
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'TEMPSKUxLOC table'
         SELECT * FROM #TEMPSKUxLOC WITH (NOLOCK)
         ORDER BY ReplenishmentPriority, ReplenishmentSeverity desc, Storerkey, Sku, LOc
      END

      SELECT @n_starttcnt=@@TRANCOUNT
      BEGIN TRANSACTION
      WHILE (1=1) -- while 1
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
         IF @b_debug = 1
         BEGIN
            Print 'Working on @c_CurrentPriority:' + dbo.fnc_RTrim(@c_CurrentPriority)
         END 
         SET ROWCOUNT 0
         /* Loop through SKUxLOC for the currentSKU, current storer */
         /* to pickup the next severity */
         SELECT @n_CurrentSeverity = 999999999
         WHILE (1=1) -- while 2
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
            IF @b_debug = 1
            BEGIN
               Print 'Working on @n_CurrentSeverity:' + dbo.fnc_RTrim(@n_CurrentSeverity)
            END 

            /* Now - for this priority, this severity - find the next storer row */
            /* that matches */
            SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15)
            WHILE (1=1) -- while 3
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
               IF @b_debug = 1
               BEGIN
                  Print 'Working on @c_CurrentStorer:' + dbo.fnc_RTrim(@c_CurrentStorer)
               END 
               /* Now - for this priority, this severity - find the next SKU row */
               /* that matches */

               -- Replenishment  - START
               SELECT @c_CurrentSKU = SPACE(20)
               WHILE (1=1) -- while 4
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_CurrentSKU = SKU
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
                  
                  IF @b_debug = 1
                  BEGIN
                     Print 'Working on @c_CurrentSKU:' + dbo.fnc_RTrim(@c_CurrentSKU) 
                  END 
                 
                  SELECT @c_CurrentLOC = SPACE(10)
                  WHILE (1=1) -- while 4
                  BEGIN
                     SET ROWCOUNT 1
                     SELECT @c_CurrentStorer = StorerKey ,
                              @c_CurrentSKU = SKU,
                              @c_CurrentLOC = LOC,
                              @n_currentFullCase = ReplenishmentCasecnt
                     FROM #TempSKUxLOC
                     WHERE LOC > @c_CurrentLOC
                     AND SKU = @c_CurrentSKU 
                     AND StorerKey = @c_CurrentStorer
                     AND ReplenishmentSeverity = @n_CurrentSeverity
                     AND ReplenishmentPriority = @c_CurrentPriority
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
      
                     /* We now have a pickLocation that needs to be replenished! */
                     /* Figure out which Locations in the warehouse to pull this product from */
                     /* End figure out which Locations in the warehouse to pull this product from */
                     SELECT @c_FromLOC = SPACE(10),  
                           @c_fromlot = SPACE(10), 
                              @c_fromid = SPACE(18),
                              @n_FromQty = 0, @n_PossibleCases = 0,
                              @n_remainingqty = @n_CurrentSeverity * @n_CurrentFullCase, -- by jeff, used to calculate qty required per LOT, rather than from SKUxLOC
                              @n_remainingcases = @n_CurrentSeverity,
                              @c_fromlot2 = SPACE(10),
                              @b_DoneCheckOverAllocatedLots = 0
                            
                     DECLARE     @c_uniquekey NVARCHAR(60), @c_uniquekey2 NVARCHAR(60)
                     
                     SELECT @c_uniquekey = '', @c_uniquekey2 = ''
                     SET ROWCOUNT 1
                     SELECT @c_fromlot2 = LLI.LOT 
                     FROM LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC 
                     JOIN LOTATTRIBUTE WITH (NOLOCK) ON LLI.SKU = LOTATTRIBUTE.SKU AND LLI.STORERKEY = LOTATTRIBUTE.STORERKEY
                                                      AND LLI.LOT = LOTATTRIBUTE.LOT
                     JOIN LOT WITH (NOLOCK) ON LLI.LOT = LOT.LOT
                     WHERE LLI.LOT > @c_fromlot2
                     AND LLI.StorerKey = @c_CurrentStorer
                     AND LLI.SKU = @c_CurrentSKU                     
                     AND LOC.LocationFlag <> "DAMAGE"
                     AND LOC.LocationFlag <> "HOLD"
                     AND LOC.Status <> "HOLD"
                     AND ((LLI.QtyAllocated + LLI.qtypicked) - LLI.qty) > 0 -- SOS 6217
                     AND LLI.LOC = @c_CurrentLOC
                     AND LOT.Status <> "HOLD"
                     AND LOC.Facility = @c_zone01
                     --AND LLI.Storerkey BETWEEN @c_zone08 AND @c_Zone08End -- #89979
               AND (LLI.Storerkey = @c_Storerkey OR @c_Storerkey='ALL')
                     AND LLI.SKU BETWEEN @c_zone09 AND @c_zone10 -- #89979
                     AND LOTATTRIBUTE.Lottable02 <> '02000' -- SOS# 64895
                     ORDER BY LLI.LOT 
   
                     IF @@ROWCOUNT = 0
                     BEGIN   
                        SELECT @c_fromlot = LOTxLOCxID.LOT,
                                 @c_fromloc = LOTxLOCxID.LOC,
                                 @c_fromid  = LOTxLOCxID.ID,
                                 @n_OnHandQty = LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked),
                                 @c_uniquekey2= RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) +  -- #89979
                                                CONVERT(char(20), isnull(LOTATTRIBUTE.Lottable05,'') ,112)+  -- #89979
                                                CASE LOC.LocationHandling   WHEN '2'
                                                   THEN '05'
                                                   WHEN '1'
                                                   THEN '10'
                                                   WHEN '9'
                                                   THEN '15'
                                                   ELSE '99'
                                             END +   
                                             LOTxLOCxID.LOC + LOTxLOCxID.LOT + LOTxLOCxID.ID
                        FROM LOTxLOCxID WITH (NOLOCK) 
                              JOIN LOC WITH (NOLOCK) ON  (LOTxLOCxID.LOC = LOC.LOC)
                                                   AND (LOC.LocationFlag <> "DAMAGE")
                                                   AND (LOC.LocationFlag <> "HOLD")
                                          --       AND (LOC.LocationType <> "BBA") -- added by Jeff - Do not replenish from BBA
                                                   AND (LOC.Status <> "HOLD")
                              JOIN SKUXLOC WITH (NOLOCK) ON  (LOTxLOCxID.StorerKey = SKUXLOC.Storerkey)
                                                   AND (LOTxLOCxID.SKU = SKUXLOC.SKU)
                                                   AND (LOTxLOCxID.LOC = SKUXLOC.LOC)
                                                   AND (SKUXLOC.LOCATIONTYPE <> "CASE")
                                                   AND (SKUXLOC.LOCATIONTYPE <> "PICK")
                                                   AND (SKUXLOC.QtyExpected = 0)
                              JOIN ID WITH (NOLOCK) ON  (LOTxLOCxID.ID = ID.ID)
                                                   AND (ID.Status <> "HOLD")
                              JOIN LOT WITH (NOLOCK) ON  (LOTxLOCxID.LOT = LOT.LOT)
                                                   AND (LOT.Status <> "HOLD")
                              JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT -- SOS# 64895
                        WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
                        AND LOTxLOCxID.SKU = @c_CurrentSKU
                        AND LOTxLOCxID.LOC <> @c_CurrentLOC
                        AND LOC.Facility   = @c_zone01
                        AND LOTxLOCxID.Lot = @c_fromlot2
                        AND ( LOTxLOCxID.qtyexpected = 0 )
                        AND LOTATTRIBUTE.Lottable02 <> '02000'
                        AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
                        AND NOT EXISTS ( SELECT 1 
                                          FROM #REPLENISHMENT
                                          WHERE #REPLENISHMENT.Lot     = LOTxLOCxID.LOT
                                          AND   #REPLENISHMENT.FromLoc = LOTxLOCxID.LOC
                                          AND   #REPLENISHMENT.ID      = LOTxLOCxID.ID
                                          GROUP BY #REPLENISHMENT.Lot, #REPLENISHMENT.FromLoc, #REPLENISHMENT.ID
                                          HAVING (LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked)) - SUM(#REPLENISHMENT.Qty) <= 0)
                        ORDER BY LOTATTRIBUTE.Lottable05, LOTxLOCxID.Qty,   -- #89979
                                 CASE LOC.LocationType WHEN "BBA"
                                    THEN '05'
                                    ELSE '99'
                                    END,
                                 CASE LOC.LocationHandling   WHEN '2'
                                       THEN '05'
                                       WHEN '1'
                                       THEN '10'
                                       WHEN '9'
                                       THEN '15'
                                       ELSE '99'
                                 END,
                                 LOTxLOCxID.Loc ,LOTxLOCxID.Lot, LOTxLOCxID.ID DESC
      
                                             
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SET ROWCOUNT 0
                           GOTO GET_REPLENISH_RECORD
                        END
                     END
                     SET ROWCOUNT 0
   
                     WHILE (1=1 AND @n_remainingqty > 0)  -- while 5
                     BEGIN
           
                           SET ROWCOUNT 1
                           SELECT @c_fromlot = LOTxLOCxID.LOT,
                                    @c_fromloc = LOTxLOCxID.LOC,
                                    @c_fromid  = LOTxLOCxID.ID,
                                    @n_OnHandQty = LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked),
                                    @c_uniquekey = RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) + -- #89979
                                                   CONVERT(char(20), isnull(LOTATTRIBUTE.Lottable05,'') ,112) + 
                                                   CASE LOC.LocationHandling   WHEN '2'
                                                         THEN '05'
                                                         WHEN '1'
                                                         THEN '10'
                                                         WHEN '9'
                                                         THEN '15'
                                                         ELSE '99'
                                                   END + 
                                                   LOTxLOCxID.LOC + LOTxLOCxID.LOT
                           FROM LOTxLOCxID WITH (NOLOCK) 
                                 JOIN LOC WITH (NOLOCK)     ON  (LOTxLOCxID.LOC = LOC.LOC)
                                                      AND (LOC.LocationFlag <> "DAMAGE")
                                                      AND (LOC.LocationFlag <> "HOLD")
                                                      AND (LOC.Status <> "HOLD")
                                 JOIN SKUXLOC WITH (NOLOCK) ON  (LOTxLOCxID.StorerKey = SKUXLOC.Storerkey)
                                                      AND (LOTxLOCxID.SKU = SKUXLOC.SKU)
                                                      AND (LOTxLOCxID.LOC = SKUXLOC.LOC)
                                                      AND (SKUXLOC.LOCATIONTYPE <> "CASE")
                                                      AND (SKUXLOC.LOCATIONTYPE <> "PICK")
                                                      AND (SKUXLOC.QtyExpected = 0)
                                 JOIN ID WITH (NOLOCK) ON  (LOTxLOCxID.ID = ID.ID)
                                                      AND (ID.Status <> "HOLD")
                                 JOIN LOT WITH (NOLOCK) ON  (LOTxLOCxID.LOT = LOT.LOT)
                                                      AND (LOT.Status <> "HOLD") 
                                 JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT -- SOS# 64895
                           WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_CurrentSKU
                           AND LOTxLOCxID.LOC <> @c_CurrentLOC
                           AND LOC.Facility   = @c_zone01
                           AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
                           AND ( LOTxLOCxID.qtyexpected = 0 )
                           AND ((( RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) + CONVERT(char(20), isnull(LOTATTRIBUTE.Lottable05,'') ,112)+ -- #89979
                                    CASE LOC.LocationHandling   WHEN '2'
                                          THEN '05'
                                          WHEN '1'
                                          THEN '10'
                                          WHEN '9'
                                          THEN '15'
                                          ELSE '99'
                                    END + 
                                          LOTxLOCxID.LOC + LOTxLOCxID.LOT >= @c_uniquekey AND LOTxLOCxID.Id < @c_fromid)
                           OR ( RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) +CONVERT(char(20), isnull(LOTATTRIBUTE.Lottable05,'') ,112)+ -- #89979
                                 CASE LOC.LocationHandling   WHEN '2'
                                          THEN '05'
                                          WHEN '1'
                                          THEN '10'
                                          WHEN '9'
                                          THEN '15'
                                          ELSE '99'
                                    END +  
                                          LOTxLOCxID.LOC + LOTxLOCxID.LOT > @c_uniquekey )) 
                           AND (RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) + CONVERT(char(20), isnull(LOTATTRIBUTE.Lottable05,'') ,112)+ -- #89979
                                 CASE LOC.LocationHandling   WHEN '2'
                                                   THEN '05'
                                                   WHEN '1'
                                                   THEN '10'
                                                   WHEN '9'
                                                   THEN '15'
                                                   ELSE '99'
                                             END + 
                                             LOTxLOCxID.LOC + LOTxLOCxID.LOT + LOTxLOCxID.ID <> @c_uniquekey2 ))
                           AND LOTATTRIBUTE.Lottable02 <> '02000'
                           AND NOT EXISTS ( SELECT 1 
                                          FROM #REPLENISHMENT
                                          WHERE #REPLENISHMENT.Lot     = LOTxLOCxID.LOT
                                          AND   #REPLENISHMENT.FromLoc = LOTxLOCxID.LOC
                                          AND   #REPLENISHMENT.ID      = LOTxLOCxID.ID
                                          GROUP BY #REPLENISHMENT.Lot, #REPLENISHMENT.FromLoc, #REPLENISHMENT.ID 
                                          HAVING (LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked)) - SUM(#REPLENISHMENT.Qty) <= 0  )
                           ORDER BY LOTATTRIBUTE.Lottable05, LOTxLOCxID.Qty, -- #89979
                                    CASE LOC.LocationType WHEN "BBA" 
                                       THEN '05'
                                       ELSE '99'
                                       END,
                                    CASE LOC.LocationHandling   WHEN '2'
                                          THEN '05'
                                          WHEN '1'
                                          THEN '10'
                                          WHEN '9'
                                          THEN '15'
                                          ELSE '99'
                                    END,
                                    LOTxLOCxID.Loc ,LOTxLOCxID.Lot, LOTxLOCxID.ID DESC                                                     

                           IF @@ROWCOUNT = 0
                           BEGIN
                              IF @b_debug = 1
                                 SELECT 'Not Lot Available! SKU= ' + @c_CurrentSKU + ' LOC=' + @c_CurrentLOC
                              SET ROWCOUNT 0
                              BREAK
                           END
                           ELSE
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Lot picked from LOTxLOCxID' , @c_fromlot
                              END
                           END 
                           SET ROWCOUNT 0

                           IF @b_debug = 1
                              BEGIN

                                 SELECT lot, fromloc, id, @n_OnHandQty - SUM(#REPLENISHMENT.Qty), @n_OnHandQty onhandqty, SUM(#REPLENISHMENT.Qty) replqty   
                                 from  #REPLENISHMENT
                                 where #REPLENISHMENT.Lot     = @c_fromlot
                                 AND   #REPLENISHMENT.FromLoc = @c_fromloc
                                 AND   #REPLENISHMENT.ID      = @c_fromid
                                 group by #REPLENISHMENT.Lot, #REPLENISHMENT.FromLoc, #REPLENISHMENT.ID 
                              END
                           IF @b_debug = 1
                           BEGIN
                              SELECT 'SELECTed Lot' , @c_fromlot
                           END
                    
                           GET_REPLENISH_RECORD:

                           SELECT @n_OnHandQty = @n_OnHandQty - SUM(#REPLENISHMENT.Qty)
                           FROM #REPLENISHMENT
                           WHERE #REPLENISHMENT.Lot     = @c_fromlot
                           AND   #REPLENISHMENT.FromLoc = @c_fromloc
                           AND   #REPLENISHMENT.ID      = @c_fromid
                           GROUP BY #REPLENISHMENT.Lot, #REPLENISHMENT.FromLoc, #REPLENISHMENT.ID 

                           /* How many cases can I get from this record? */
                           SELECT @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullCase)
                           IF @b_debug = 1
                           BEGIN
                              SELECT '@n_OnHandQty' = @n_OnHandQty , '@n_RemainingQty' = @n_RemainingQty
                              SELECT '@n_possiblecases' = @n_possiblecases , '@n_currentFullCase' = @n_currentFullCase
                           END
                           /* How many do we take? */
                           IF @n_OnHandQty > @n_RemainingQty
                           BEGIN
                              -- Modify by SHONG for full carton only
                              SELECT @n_FromQty = @n_RemainingQty
                              SELECT @n_RemainingQty = 0
                                 END
                           ELSE
                           BEGIN
                              -- Modify by shong for full carton only
   
                              IF @n_OnHandQty > @n_CurrentFullCase
                              BEGIN 
                                 SELECT @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase)
                              END
                              ELSE
                              BEGIN
                                 SELECT @n_FromQty = @n_OnHandQty
                              END
                               
                              SELECT @n_remainingqty = @n_remainingqty - @n_FromQty
                             
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Checking possible cases AND current full case available - @n_RemainingQty > @n_FromQty'
                                 SELECT '@n_possiblecases' = @n_possiblecases , '@n_currentFullCase' = @n_currentFullCase
                                 SELECT '@n_FromQty' = @n_FromQty
                              END
                           END
                      
                           IF @n_FromQty > 0
                           BEGIN
                              SELECT @c_Packkey = PACK.PackKey,
                                       @c_UOM = PACK.PackUOM3
                              FROM   SKU WITH (NOLOCK)
                              JOIN PACK WITH (NOLOCK) ON SKU.PackKey = PACK.Packkey
                              WHERE  SKU.StorerKey = @c_CurrentStorer
                              AND    SKU.SKU = @c_CurrentSKU
                              -- print 'before insert into replenishment'
                              -- SELECT @n_fromqty 'fromqty', @n_possiblecases 'possiblecases', @n_remainingqty 'remainingqty'
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
                              SELECT @c_CurrentSKU ' SKU', @c_CurrentLOC 'LOC', @c_CurrentPriority 'priority', @n_CurrentFullCase 'full case', @n_CurrentSeverity 'severity'
                              -- SELECT @n_FromQty 'qty', @c_FromLOC 'fromLOC', @c_fromlot 'from lot', @n_PossibleCases 'possible cases'
                              SELECT @n_remainingqty '@n_remainingqty', @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU, @c_fromlot 'from lot', @c_fromid
                           END
                     
                        END -- SCAN LOT FOR LOT
                        SET ROWCOUNT 0
                     END  -- FOR LOC
                     SET ROWCOUNT 0
                  END -- FOR SKU
                  -- Replenishment  - END
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
         UPDATE #REPLENISHMENT WITH (ROWLOCK) 
         SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked
         FROM SKUxLOC WITH (NOLOCK)
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
   FROM   #REPLENISHMENT R
   OPEN CUR1

   FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLOC, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
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
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into Replenishment table failed. (isp_ReplenishmentRpt_BatchRefill_13)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ReplenishmentRpt_BatchRefill_13'
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
   IF @c_FuncType = 'G'                                       
   BEGIN  
     RETURN
   END
   --(Wan01) - END  

   IF ( @c_zone02 = 'ALL')
   BEGIN
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, L1.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, 
      (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked), LA.Lottable02, LA.Lottable04, SKU.Size 
      FROM  REPLENISHMENT R WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
      JOIN LOC L1 WITH (NOLOCK) ON L1.Loc = R.ToLoc
      JOIN LOC L2 WITH (NOLOCK) ON L2.Loc = R.FromLoc
      JOIN PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
      JOIN LOTxLOCxID LLI WITH (NOLOCK) ON LLI.Lot = R.Lot AND LLI.Loc = R.FromLoc AND LLI.ID = R.ID
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.LOT = LA.LOT AND LLI.SKU = LA.SKU AND LLI.STORERKEY = LA.STORERKEY 
      WHERE R.confirmed = 'N'
      AND  L1.Facility = @c_zone01        
      --AND  LLI.Storerkey BETWEEN @c_zone08 AND @c_Zone08End -- #89979
      AND (LLI.Storerkey = @c_Storerkey OR @c_Storerkey='ALL')
      AND  LLI.SKU BETWEEN @c_zone09 AND @c_zone10 -- #89979
      AND  L1.LocAisle BETWEEN @c_zone11 AND @c_zone12 -- #89979
      AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)  
      -- Start : SOS90109 - June01
      -- ORDER BY L1.PutawayZone, R.Priority, SKU.SKU
      ORDER BY L1.PutawayZone, R.Priority, SUBSTRING(R.FromLoc, 1, 4), SUBSTRING(R.FromLoc, 9, 2), SUBSTRING(R.FromLoc, 6, 2), SKU.SKU
      -- End : SOS90109 - June01
   END
   ELSE
   BEGIN
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, L1.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey,
      (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked), LA.Lottable02, LA.Lottable04, SKU.Size  
      FROM  REPLENISHMENT R WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
      JOIN LOC L1 WITH (NOLOCK) ON L1.Loc = R.ToLoc
      JOIN LOC L2 WITH (NOLOCK) ON L2.Loc = R.FromLoc
      JOIN PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
      JOIN LOTxLOCxID LLI WITH (NOLOCK) ON LLI.Lot = R.Lot AND LLI.Loc = R.FromLoc AND LLI.ID = R.ID
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.LOT = LA.LOT AND LLI.SKU = LA.SKU AND LLI.STORERKEY = LA.STORERKEY
      WHERE R.confirmed = 'N'
      AND  L1.Facility = @c_zone01
      --AND   L1.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12) -- #89979
      AND   L1.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07)-- #89979
      --AND   LLI.Storerkey BETWEEN @c_zone08 AND @c_Zone08End -- #89979
      AND   (LLI.Storerkey = @c_Storerkey OR @c_Storerkey='ALL')
      AND   LLI.SKU BETWEEN @c_zone09 AND @c_zone10 -- #89979
      AND   L1.LocAisle BETWEEN @c_zone11 AND @c_zone12 -- #89979
      AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)  
      -- Start : SOS90109 - June01
      -- ORDER BY L1.PutawayZone, R.Priority, SKU.SKU
      ORDER BY L1.PutawayZone, R.Priority, SUBSTRING(R.FromLoc, 1, 4), SUBSTRING(R.FromLoc, 9, 2), SUBSTRING(R.FromLoc, 6, 2), SKU.SKU
      -- End : SOS90109 - June01
   END

END

GO