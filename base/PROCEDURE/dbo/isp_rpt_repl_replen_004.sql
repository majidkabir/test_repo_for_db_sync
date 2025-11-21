SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_REPL_REPLEN_004                               */
/* Creation Date: 09-DEC-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:  Priyanka                                                   */
/*                                                                         */
/* Purpose: WMS-18551                                                      */
/*                                                                         */
/* Called By: RPT_REPL_REPLEN_004                                          */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 04-Jan-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE PROC [dbo].[isp_RPT_REPL_REPLEN_004]
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
,              @c_Storerkey   NVARCHAR(15)
,              @c_ReplGrp     NVARCHAR(30) = 'ALL'
,              @c_Functype    NCHAR(1) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   DECLARE @b_debug int,
           @c_Packkey NVARCHAR(10),
           @c_UOM     NVARCHAR(10),
           @n_FullPallet int,
           @n_PalletCnt  int,
           @n_CaseCnt  int,
           @n_LooseQty int


   DECLARE @c_SQL            NVARCHAR(MAX) = ''
         , @c_Condition      NVARCHAR(MAX) = ''
         , @c_OrderBy        NVARCHAR(MAX) = ''
         , @c_PZone          NVARCHAR(50)  = ''
         , @c_Sorting        NVARCHAR(100) = ''
         , @c_OrderByPZone   NVARCHAR(MAX) = ''

   CREATE TABLE #TMP_SORTING (
      PZone    NVARCHAR(50)
    , Sorting  NVARCHAR(100)
   )



   INSERT INTO #TMP_SORTING(PZone, Sorting)
   SELECT DISTINCT ISNULL(CL.Code,''), REPLACE(ISNULL(CL.UDF01,''),'Replenishment','R')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPLENSORT'
   AND CL.Storerkey = @c_Storerkey


   SELECT @n_continue=1,
   @b_debug = 0

   IF @c_zone12 = '1'
   BEGIN
      SELECT @b_debug = CAST( @c_zone12 AS int)
      SELECT @c_zone12 = ''
   END


   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END

   IF @c_FuncType IN ( 'P' )
   BEGIN
      GOTO QUIT_SP
   END


   DECLARE @c_priority  NVARCHAR(5)
   SELECT StorerKey, SKU, LOC FromLOC, LOC ToLOC, Lot, Id, Qty, Qty QtyMoved, Qty QtyInPickLOC,
   @c_priority Priority, Lot UOM, Lot PackKey, '0' RefNo
   INTO #REPLENISHMENT
   FROM LOTXLOCXID (NOLOCK)
   WHERE 1 = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_CurrentSKU                  NVARCHAR(20)
             ,@c_CurrentStorer               NVARCHAR(15)
             ,@c_CurrentLoc                  NVARCHAR(10)
             ,@c_CurrentPriority             NVARCHAR(5)
             ,@n_currentfullcase             INT
             ,@n_CurrentSeverity             INT
             ,@c_FromLOC                     NVARCHAR(10)
             ,@c_fromlot                     NVARCHAR(10)
             ,@c_fromid                      NVARCHAR(18)
             ,@n_FromQty                     INT
             ,@n_remainingqty                INT
             ,@n_possiblecases               INT
             ,@n_remainingcases              INT
             ,@n_OnHandQty                   INT
             ,@n_fromcases                   INT
             ,@c_ReplenishmentKey            NVARCHAR(10)
             ,@n_numberofrecs                INT
             ,@n_limitrecs                   INT
             ,@c_fromlot2                    NVARCHAR(10)
             ,@b_DoneCheckOverAllocatedLots  INT
             ,@n_SKULOCavailableqty          INT
             ,@c_hostwhcode                  NVARCHAR(10)
             ,@c_overallocation              NVARCHAR(1)
             ,@c_Sku                         NVARCHAR(20)

      SELECT @c_CurrentSKU = SPACE(20)
            ,@c_CurrentStorer = SPACE(15)
            ,@c_CurrentLoc = SPACE(10)
            ,@c_CurrentPriority = SPACE(5)
            ,@n_currentfullcase = 0
            ,@n_CurrentSeverity = 9999999
            ,@n_FromQty = 0
            ,@n_remainingqty = 0
            ,@n_possiblecases = 0
            ,@n_remainingcases = 0
            ,@n_fromcases = 0
            ,@n_numberofrecs = 0
            ,@n_limitrecs = 5


      CREATE TABLE #TMP_SKU (Storerkey NVARCHAR(15), Sku NVARCHAR(20), Lottable04 DATETIME NULL, OverallocatedSKU NVARCHAR(5))

      /* Make a temp version of SKUxLOC */
      SELECT ReplenishmentPriority, ReplenishmentSeverity ,StorerKey,
      SKU, LOC, ReplenishmentCasecnt, 'N' AS Overallocation
      INTO #TempSKUxLOC
      FROM SKUxLOC (NOLOCK)
      WHERE 1=2


      -- Use Left Outer Join for LOTxLOCxID


      INSERT #TempSKUxLOC
      SELECT MIN(ReplenishmentPriority),
      ReplenishmentSeverity = CASE WHEN ISNULL(SUM(LOTxLOCxID.QtyExpected),0) > 0
                                     AND MIN(SKUxLOC.QtyLocationMinimum) < SUM(ISNULL(LOTxLOCxID.Qty - (LOTxLOCxID.QtyPicked + LOTxLOCxID.QtyAllocated),0)) THEN
                                            ISNULL(SUM(LOTxLOCxID.QtyExpected),0)
                                   ELSE MAX(SKUxLOC.QtyLocationLimit) - SUM( ISNULL(LOTxLOCxID.Qty - (LOTxLOCxID.QtyPicked + LOTxLOCxID.QtyAllocated),0 ))
                              END,
      SKUxLOC.StorerKey,
      MIN(SKUxLOC.SKU),
      SKUxLOC.LOC,
      MAX(ReplenishmentCasecnt),
      OverAllocation = CASE WHEN ISNULL(SUM(LOTxLOCxID.QtyExpected),0) > 0
                              AND MIN(SKUxLOC.QtyLocationMinimum) < SUM(ISNULL(LOTxLOCxID.Qty - (LOTxLOCxID.QtyPicked + LOTxLOCxID.QtyAllocated),0)) THEN
                                 'Y'
                            ELSE 'N' END
      FROM SKUxLOC (NOLOCK)
      JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
      JOIN SKU (NOLOCK) ON SKU.StorerKey = SKUxLOC.StorerKey
                               AND  SKU.SKU = SKUxLOC.SKU
      LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON SKUxLOC.Storerkey = LOTxLOCxID.Storerkey
                               AND  SKUxLOC.Sku = LOTxLOCxID.Sku
                                AND  SKUxLOC.Loc = LOTxLOCxID.Loc
      WHERE  (SKUxLOC.LOCationtype = 'PICK' or SKUxLOC.LOCationtype = 'CASE')
      AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')
      AND  LOC.FACILITY = @c_Zone01
      AND  (LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
            OR @c_zone02 = 'ALL')
      GROUP BY
               SKUxLOC.StorerKey,
               SKUxLOC.LOC

      HAVING SUM(LOTxLOCxID.QtyExpected) > 0 OR
            (SUM(ISNULL(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated,0)) <= MIN(SKUxLOC.QtyLocationMinimum) )

      /*
      INSERT #TempSKUxLOC
      SELECT ReplenishmentPriority,
      ReplenishmentSeverity = CASE WHEN ISNULL(SUM(LOTxLOCxID.QtyExpected),0) > 0
                                     AND SKUxLOC.QtyLocationMinimum < (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated)) THEN
                                            ISNULL(SUM(LOTxLOCxID.QtyExpected),0)
                                   ELSE SKUxLOC.QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))
                              END,
      SKUxLOC.StorerKey,
      SKUxLOC.SKU,
      SKUxLOC.LOC,
      ReplenishmentCasecnt,
      OverAllocation = CASE WHEN ISNULL(SUM(LOTxLOCxID.QtyExpected),0) > 0
                              AND SKUxLOC.QtyLocationMinimum < (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated)) THEN
                                 'Y'
                            ELSE 'N' END
      FROM SKUxLOC (NOLOCK)
      JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
      JOIN SKU (NOLOCK) ON SKU.StorerKey = SKUxLOC.StorerKey
                               AND  SKU.SKU = SKUxLOC.SKU
      LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON SKUxLOC.Storerkey = LOTxLOCxID.Storerkey
                               AND  SKUxLOC.Sku = LOTxLOCxID.Sku
                                AND  SKUxLOC.Loc = LOTxLOCxID.Loc
      WHERE  (SKUxLOC.LOCationtype = 'PICK' or SKUxLOC.LOCationtype = 'CASE')
      AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')
      AND  LOC.FACILITY = @c_Zone01
      AND  (LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
            OR @c_zone02 = 'ALL')
      GROUP BY SKUxLOC.ReplenishmentPriority,
               SKUxLOC.StorerKey,
               SKUxLOC.SKU,
               SKUxLOC.LOC,
               SKUxLOC.ReplenishmentCasecnt,
               SKUxLOC.Qty,
               SKUxLOC.QtyPicked,
               SKUxLOC.QtyAllocated,
               SKUxLOC.QtyLocationMinimum,
               SKUxLOC.QtyLocationLimit
      HAVING SUM(LOTxLOCxID.QtyExpected) > 0 OR
            (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
      */


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
         @n_CurrentSeverity = ReplenishmentSeverity,
         @c_overallocation  = OverAllocation
         FROM #TempSKUxLOC
         WHERE SKU > @c_CurrentSKU

--       AND StorerKey = @c_CurrentStorer
         ORDER BY SKU
         IF @@ROWCOUNT = 0
         BEGIN
            SET ROWCOUNT 0
            BREAK
         END
         SET ROWCOUNT 0

         select @c_hostwhcode = hostwhcode
         from loc (nolock)
         where loc = @c_CurrentLoc

         /* We now have a pickLOCation that needs to be replenished! */
         /* Figure out which LOCations in the warehouse to pull this product from */
         /* End figure out which LOCations in the warehouse to pull this product from */
         SELECT @c_FromLOC = SPACE(10),  @c_fromlot = SPACE(10), @c_fromid = SPACE(18),
         @n_FromQty = 0, @n_possiblecases = 0,
         @n_Remainingqty = @n_CurrentSeverity,
         -- @n_Remainingqty = @n_CurrentSeverity * @n_currentfullcase,
         @n_remainingcases = CASE WHEN @n_currentfullcase > 0
                                  THEN @n_CurrentSeverity / @n_currentfullcase
                                  ELSE @n_CurrentSeverity
                             END,
         @c_fromlot2 = SPACE(10),
         @b_DoneCheckOverAllocatedLots = 0


         TRUNCATE TABLE #TMP_SKU

         INSERT INTO #TMP_SKU (Storerkey, Sku, Lottable04, OverallocatedSKU)
         SELECT SL.Storerkey, SL.Sku, INV.Lottable04, 'N'
         FROM SKUXLOC SL(NOLOCK)
         OUTER APPLY (SELECT MIN(LA.Lottable04) AS Lottable04,
                             SUM(LLI.QtyExpected) AS QtyExpected
                      FROM LOTXLOCXID LLI(NOLOCK)
                      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                      JOIN ID (NOLOCK) ON LLI.ID = ID.Id
                      JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
                      JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                      WHERE LOC.HostWHCode = @c_HostWHCode
                      AND LOC.Facility = @c_Zone01
                      AND LLI.Storerkey = SL.Storerkey
                      AND LLI.Sku = SL.Sku
                      AND LLI.Loc <> @c_CurrentLoc
                      AND LOC.LocationFlag = 'NONE'
                      AND LOC.Status = 'OK'
                      AND ID.Status = 'OK'
                      AND LOT.Status = 'OK'
                      AND LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated > 0) INV
         WHERE SL.Storerkey = @c_CurrentStorer
         AND SL.Loc = @c_CurrentLoc
         AND SL.LocationType IN('PICK','CASE')

         SELECT LOTxLOCxID.LOT, 'OVERALLOC' AS Overallocation
         INTO #TMP_OVERALLOC
         FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOT (NOLOCK)
         WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
         --AND LOTxLOCxID.SKU = @c_CurrentSKU
         AND LOTxLOCxID.LOC = LOC.LOC
         AND LOTxLOCxID.QtyExpected > 0
         AND LOTxLOCxID.LOC = @c_CurrentLoc
         AND LOTxLOCxID.LOT = LOT.Lot
         AND LOT.Status     = 'OK'
         GROUP BY LOTxLOCxID.LOT


         UPDATE #TMP_SKU
         SET #TMP_SKU.OverallocatedSKU = 'Y'
         WHERE #TMP_SKU.Sku IN (SELECT LOT.Sku FROM #TMP_OVERALLOC JOIN LOT (NOLOCK) ON #TMP_OVERALLOC.Lot = LOT.Lot)


         DECLARE LOT_CUR CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOT, LOTxLOCxID.Sku
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
         JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
         JOIN LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.Lot
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID  = ID.ID
         JOIN #TMP_SKU TSKU (NOLOCK) ON LOTxLOCxID.Storerkey = TSKU.Storerkey AND LOTxLOCxID.Sku = TSKU.Sku
         LEFT JOIN #TMP_OVERALLOC ON LOTxLOCxID.Lot = #TMP_OVERALLOC.Lot
         WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
         --AND LOTxLOCxID.SKU = @c_CurrentSKU
         AND LOC.LocationFlag <> 'DAMAGE'
         AND LOC.LocationFlag <> 'HOLD'
         AND LOC.Status <> 'HOLD'
         AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0
         AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demand
         AND LOTxLOCxID.LOC <> @c_CurrentLoc
         AND LOC.Facility = @c_zone01
         AND LOC.hostwhcode = @c_hostwhcode

         -- AND (LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         --        OR @c_zone02 = 'ALL')
         AND LOT.Status     = 'OK'
         AND ID.Status      <> 'HOLD'
         GROUP BY LOTxLOCxID.LOT, ISNULL(#TMP_OVERALLOC.Overallocation,''), LOTxLOCxID.Sku, TSKU.OverallocatedSku
       ORDER BY CASE WHEN ISNULL(#TMP_OVERALLOC.Overallocation,'')='OVERALLOC' THEN 1 ELSE 2 END, CASE WHEN TSKU.OverallocatedSku = 'Y' THEN 1 ELSE 2 END,
                MIN(TSKU.Lottable04), LOTxLOCxID.Sku, MIN(LOTATTRIBUTE.LOTTABLE04), MIN(LOTATTRIBUTE.LOTTABLE05)
         /*
         DECLARE LOT_CUR CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOT
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
         JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
         JOIN LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.Lot
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID  = ID.ID
         LEFT JOIN #TMP_OVERALLOC ON LOTxLOCxID.Lot = #TMP_OVERALLOC.Lot
         WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
         AND LOTxLOCxID.SKU = @c_CurrentSKU
         AND LOC.LocationFlag <> 'DAMAGE'
         AND LOC.LocationFlag <> 'HOLD'
         AND LOC.Status <> 'HOLD'
         AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0
         AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demand
         AND LOTxLOCxID.LOC <> @c_CurrentLoc
         AND LOC.Facility = @c_zone01
         AND LOC.hostwhcode = @c_hostwhcode

         AND LOT.Status     = 'OK'
         AND ID.Status      <> 'HOLD'
         GROUP BY LOTxLOCxID.LOT, ISNULL(#TMP_OVERALLOC.Overallocation,'')
         ORDER BY CASE WHEN ISNULL(#TMP_OVERALLOC.Overallocation,'')='OVERALLOC' THEN 1 ELSE 2 END,
                            MIN(LOTTABLE04), MIN(LOTTABLE05)
         */

         OPEN LOT_CUR

         FETCH NEXT FROM LOT_CUR INTO @c_FromLot, @c_Sku
         WHILE @@Fetch_Status <> -1 AND @n_remainingqty > 0
         BEGIN
            SET ROWCOUNT 0
            SELECT @c_FromLOC = SPACE(10)

            DECLARE LOC_CUR CURSOR FAST_FORWARD READ_ONLY FOR
               SELECT LOTxLOCxID.LOC
               FROM LOTxLOCxID (NOLOCK)
               JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
               WHERE LOTxLOCxID.LOT = @c_fromlot
               AND LOTxLOCxID.StorerKey = @c_CurrentStorer
               AND LOTxLOCxID.SKU = @c_SKU
               AND LOTxLOCxID.LOC = LOC.LOC
               AND LOC.LocationFlag <> 'DAMAGE'
               AND LOC.LocationFlag <> 'HOLD'
               AND LOC.Status <> 'HOLD'
               AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0
               AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
               AND LOTxLOCxID.LOC <> @c_CurrentLoc
               AND LOC.Facility = @c_zone01
               -- AND LOC.LocLevel > 1
               AND LOC.hostwhcode = @c_hostwhcode
               GROUP BY LOC.LogicalLocation, LOTxLOCxID.LOC
               ORDER BY SUM(LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated),
                         LOC.LogicalLocation, LOTxLOCxID.LOC

            OPEN LOC_CUR

            FETCH NEXT FROM LOC_CUR INTO @c_FromLOC

            WHILE @@Fetch_Status <> -1 AND @n_remainingqty > 0
            BEGIN
               SET ROWCOUNT 0
               SELECT @c_fromid = replicate('Z',18)
               WHILE (1=1 AND @n_remainingqty > 0)
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_fromid = ID,
                         @n_OnHandQty = LOTxLOCxID.QTY - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated
                  FROM LOTxLOCxID (NOLOCK)
                  JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
                  WHERE LOTxLOCxID.LOT = @c_fromlot
                  AND LOTxLOCxID.LOC = @c_FromLOC
                  AND LOTxLOCxID.id < @c_fromid
                  AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                  AND LOTxLOCxID.SKU = @c_SKU
                  AND LOC.LocationFlag <> 'DAMAGE'
                  AND LOC.LocationFlag <> 'HOLD'
                  AND LOC.Status <> 'HOLD'
                  AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0
                  AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                  AND LOTxLOCxID.LOC <> @c_CurrentLoc
                  AND LOC.Facility = @c_zone01
                  AND LOC.hostwhcode = @c_hostwhcode

                  -- AND (LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                  --   OR @c_zone02 = 'ALL')
                  ORDER BY ID DESC

                  IF @@ROWCOUNT = 0
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Stop because No Pallet Found! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_FromLOC
                        + ' From ID = ' + @c_fromid
                     END
                     SET ROWCOUNT 0
                     -- GOTO FIND_NEXT_LOT
                     GOTO FIND_NEXT_LOC
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
                            AND SKU = @c_SKU
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
                  AND SKU = @c_SKU
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
                  AND SKU = @c_SKU
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

                  SELECT @n_PalletCnt = ISNULL(PACK.Pallet, 0),
                         @n_CaseCnt = ISNULL(PACK.CaseCnt, 0)
                  FROM   SKU (NOLOCK)
                  JOIN   PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey
                  WHERE  SKU.StorerKey = @c_CurrentStorer
                  AND    SKU.SKU = @c_SKU

                  IF @cLocationHandling <> '2' -- Case Only
                  BEGIN
                     /* At this point, get the available qty from */
                     /* the SKUxLOC record.                       */
                     /* If it's less than what was taken from the */
                     /* lotxLOCxid record, then use it.           */
                     SELECT @n_FullPallet = QTY - QtyAllocated - QtyPicked
                     FROM LOTxLOCxID (NOLOCK)
                     WHERE StorerKey = @c_CurrentStorer
                     AND SKU = @c_SKU
                     AND LOC = @c_FromLOC
                     AND LOT = @c_fromlot
                     AND ID  = @c_fromid


                     -- If LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > Pallet Qty
                     -- Then use Pallet Qty...
                     IF @c_overallocation = 'Y'
                     BEGIN
                        IF @n_FullPallet >= @n_RemainingQty
                        BEGIN
                            SET @n_FullPallet = @n_RemainingQty
                        END
                     ELSE
                        IF @n_PalletCnt > 0 AND @n_FullPallet > @n_PalletCnt
                        BEGIN
                           SET @n_FullPallet = FLOOR(@n_FullPallet / @n_PalletCnt) * @n_PalletCnt
                        END
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

                        -- Force to replen full pallet
                        SELECT @n_FromQty = 0
                     END
                  END

                  IF @n_CaseCnt > 0 AND @n_FromQty > 0
                  BEGIN
                      SELECT @n_LooseQty = (@n_OnHandQty - @n_FromQty) % @n_CaseCnt
                      IF @n_LooseQty > 0
                      BEGIN
                         SELECT @n_FromQty = @n_FromQty + @n_LooseQty
                         SELECT @n_RemainingQty = @n_RemainingQty - @n_LooseQty
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
                     AND    SKU.SKU = @c_SKU

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
                           QtyInPickLOC,
                           Refno)
                           VALUES (
                           @c_CurrentStorer,
                           @c_SKU,
                           @c_FromLOC,
                           @c_CurrentLoc,
                           @c_fromlot,
                           @c_fromid,
                           @n_FromQty,
                           @c_UOM,
                           @c_Packkey,
                           @c_CurrentPriority,
                           0,0,
                           'N')
                        END
                     END
                     SELECT @n_numberofrecs = @n_numberofrecs + 1

                     IF @b_debug = 1
                     BEGIN
                        SELECT 'INSERTED : ' as Title, @c_SKU ' SKU', @c_fromlot 'LOT',  @c_CurrentLoc 'LOC', @c_fromid 'ID',
                               @n_FromQty 'Qty', @c_CurrentSKU ' CurrentSKU'
                     END

                  END -- if from qty > 0
                  IF @b_debug = 1
                  BEGIN
                     select @c_SKU ' SKU', @c_CurrentLoc 'LOC', @c_CurrentPriority 'priority', @n_currentfullcase 'full case', @n_CurrentSeverity 'severity', @c_CurrentSKU ' CurrentSKU'
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
               FIND_NEXT_LOC:
               FETCH NEXT FROM LOC_CUR INTO @c_FromLOC
            END -- SCAN LOT for LOC
            SET ROWCOUNT 0

            CLOSE LOC_CUR
            DEALLOCATE LOC_CUR

            FIND_NEXT_LOT:
            FETCH NEXT FROM LOT_CUR INTO @c_FromLot, @c_Sku
         END -- LOT
         CLOSE LOT_CUR
         DEALLOCATE LOT_CUR
         DROP TABLE #TMP_OVERALLOC
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


   DECLARE @n_QtyFlag INT
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM
   FROM #REPLENISHMENT R

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_FromLOC, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @n_QtyFlag = (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated))
      FROM SKUxLOC (NOLOCK)
      WHERE SKUxLOC.StorerKey = @c_CurrentStorer
      AND SKUxLOC.SKU = @c_CurrentSKU
      AND SKUxLOC.Loc = @c_CurrentLoc

      UPDATE #REPLENISHMENT
      SET RefNo = CAST(CASE WHEN @n_QtyFlag < 0 THEN 1 ELSE 0 END AS NVARCHAR(1))
      WHERE StorerKey = @c_CurrentStorer
      AND SKU = @c_CurrentSKU
      AND ToLoc = @c_CurrentLoc

      FETCH NEXT FROM CUR_LOOP INTO @c_FromLOC, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP


   /* Insert Into Replenishment Table Now */
   DECLARE @b_success int,
   @n_err     int,
   @c_errmsg  NVARCHAR(255)
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM, R.RefNo
   FROM #REPLENISHMENT R
   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM, @n_QtyFlag
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
         Confirmed,
         RefNo)
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
         'N',
         @n_QtyFlag)
         SELECT @n_err = @@ERROR

      END -- IF @b_success = 1
      FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM, @n_QtyFlag
   END -- While
   CLOSE CUR1
   DEALLOCATE CUR1
   -- End Insert Replenishment


QUIT_SP:
   IF @c_FuncType IN ( 'G' )
   BEGIN
      RETURN
   END



   DECLARE CUR_SORT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT TS.PZone, TS.Sorting
   FROM #TMP_SORTING TS
   WHERE ISNULL(TS.PZone,'') <> ''
   AND ISNULL(TS.Sorting,'') <> ''
   ORDER BY TS.PZone

   OPEN CUR_SORT

   FETCH NEXT FROM CUR_SORT INTO @c_PZone, @c_Sorting

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF ISNULL(@c_OrderByPZone,'') = ''
         SET @c_OrderByPZone = ', CASE WHEN LOC.Putawayzone = ''' + TRIM(@c_PZone) + '''' + ' THEN ' + TRIM(@c_Sorting)
      ELSE
         SET @c_OrderByPZone = @c_OrderByPZone + ' WHEN LOC.Putawayzone = ''' + TRIM(@c_PZone) + '''' + ' THEN ' + TRIM(@c_Sorting)

      FETCH NEXT FROM CUR_SORT INTO @c_PZone, @c_Sorting
   END
   CLOSE CUR_SORT
   DEALLOCATE CUR_SORT

   IF ISNULL(@c_OrderByPZone,'') <> ''
      SET @c_OrderByPZone = @c_OrderByPZone + ' ELSE R.FromLoc END'

   IF ( @c_zone02 = 'ALL')
   BEGIN


      SET @c_SQL = N'SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey
                           ,SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey
                           ,LA.Lottable04, R.RefNo
                           ,SKU.itemclass
                           ,ISNULL(PACK.InnerPack,0) AS InnerPack
                     FROM  REPLENISHMENT R (NOLOCK)
                     JOIN  SKU (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
                     JOIN  LOC (NOLOCK) ON (LOC.Loc = R.FromLoc)
                     JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
                     JOIN  LOTATTRIBUTE LA (NOLOCK) ON (R.Lot = LA.Lot)
                     WHERE LOC.facility = @c_zone01
                     AND   R.confirmed = ''N''
                     AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = ''ALL'')
                     AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = ''ALL'') '

      SET @c_OrderBy = 'ORDER BY LOC.PutawayZone, SKU.itemclass' + @c_OrderByPZone

      SET @c_SQL = @c_SQL + CHAR(13) + @c_OrderBy

      EXEC sp_executesql @c_SQL
      , N'@c_zone01      NVARCHAR(10), @c_zone02      NVARCHAR(10), @c_zone03      NVARCHAR(10),
          @c_zone04      NVARCHAR(10), @c_zone05      NVARCHAR(10), @c_zone06      NVARCHAR(10),
          @c_zone07      NVARCHAR(10), @c_zone08      NVARCHAR(10), @c_zone09      NVARCHAR(10),
          @c_zone10      NVARCHAR(10), @c_zone11      NVARCHAR(10), @c_zone12      NVARCHAR(10),
          @c_Storerkey   NVARCHAR(15), @c_ReplGrp     NVARCHAR(30) '
      , @c_zone01
      , @c_zone02
      , @c_zone03
      , @c_zone04
      , @c_zone05
      , @c_zone06
      , @c_zone07
      , @c_zone08
      , @c_zone09
      , @c_zone10
      , @c_zone11
      , @c_zone12
      , @c_Storerkey
      , @c_ReplGrp
   END
   ELSE
   BEGIN


      SET @c_SQL = N'SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey
                           ,SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey
                           ,LA.Lottable04, R.RefNo
                           ,SKU.itemclass
                           ,ISNULL(PACK.InnerPack,0) AS InnerPack
                           FROM  REPLENISHMENT R (NOLOCK), SKU (NOLOCK), LOC (NOLOCK), PACK (NOLOCK)
                           , LOTATTRIBUTE LA (NOLOCK)
                           WHERE SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
                           AND LOC.Loc = R.ToLoc
                           AND SKU.PackKey = PACK.PackKey
                           AND LA.Lot = R.Lot
                           AND LOC.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
                           and loc.facility = @c_zone01
                           AND confirmed = ''N''
                           AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = ''ALL'')
                           AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = ''ALL'') '

      SET @c_OrderBy = 'ORDER BY LOC.PutawayZone, SKU.itemclass' + @c_OrderByPZone

      SET @c_SQL = @c_SQL + CHAR(13) + @c_OrderBy

      EXEC sp_executesql @c_SQL
      , N'@c_zone01      NVARCHAR(10), @c_zone02      NVARCHAR(10), @c_zone03      NVARCHAR(10),
          @c_zone04      NVARCHAR(10), @c_zone05      NVARCHAR(10), @c_zone06      NVARCHAR(10),
          @c_zone07      NVARCHAR(10), @c_zone08      NVARCHAR(10), @c_zone09      NVARCHAR(10),
          @c_zone10      NVARCHAR(10), @c_zone11      NVARCHAR(10), @c_zone12      NVARCHAR(10),
          @c_Storerkey   NVARCHAR(15), @c_ReplGrp     NVARCHAR(30) '
      , @c_zone01
      , @c_zone02
      , @c_zone03
      , @c_zone04
      , @c_zone05
      , @c_zone06
      , @c_zone07
      , @c_zone08
      , @c_zone09
      , @c_zone10
      , @c_zone11
      , @c_zone12
      , @c_Storerkey
      , @c_ReplGrp
   END

END

GO