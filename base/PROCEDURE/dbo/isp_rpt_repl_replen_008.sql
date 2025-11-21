SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_REPL_REPLEN_008                               */
/* Creation Date: 02-MAR-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-19055                                                      */
/*                                                                         */
/* Called By: RPT_REPL_REPLEN_008                                          */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 03-Mar-2022  WLChooi 1.0   DevOps Combine Script                        */
/* 31-Oct-2023  WLChooi 1.1   UWP-10213 - Global Timezone (GTZ01)          */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_REPL_REPLEN_008]
   @c_zone01    NVARCHAR(10)
 , @c_zone02    NVARCHAR(10)
 , @c_zone03    NVARCHAR(10)
 , @c_zone04    NVARCHAR(10)
 , @c_zone05    NVARCHAR(10)
 , @c_zone06    NVARCHAR(10)
 , @c_zone07    NVARCHAR(10)
 , @c_zone08    NVARCHAR(10)
 , @c_zone09    NVARCHAR(10)
 , @c_zone10    NVARCHAR(10)
 , @c_zone11    NVARCHAR(10)
 , @c_zone12    NVARCHAR(10)
 , @c_StorerKey NVARCHAR(15) = 'ALL'
 , @c_ReplGrp   NVARCHAR(30) = 'ALL'
 , @c_Functype  NCHAR(1)     = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_continue  INT /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
         , @n_starttcnt INT

   DECLARE @b_debug            INT
         , @c_Packkey          NVARCHAR(10)
         , @c_UOM              NVARCHAR(10)
         , @n_qtytaken         INT
         , @n_ROWREF           INT
         , @n_Rowcnt           INT
         , @n_ReplenishmentKey INT

   SELECT @n_continue = 1
        , @b_debug = 0
   SELECT @n_starttcnt = @@TRANCOUNT

   IF @c_zone12 <> ''
      SELECT @b_debug = CAST(@c_zone12 AS INT)

   DECLARE @c_priority NVARCHAR(5)


   IF ISNULL(@c_ReplGrp, '') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END


   IF @c_Functype IN ( '', 'G' )
   BEGIN

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      CREATE TABLE #REPLENISHMENT
      (
         ROWREF        INT          IDENTITY(1, 1) NOT NULL PRIMARY KEY
       , REPLENISHMENT NVARCHAR(10) NOT NULL DEFAULT ''
       , StorerKey     NVARCHAR(20) NOT NULL
       , SKU           NVARCHAR(20) NOT NULL
       , FROMLOC       NVARCHAR(10) NOT NULL
       , ToLOC         NVARCHAR(10) NOT NULL
       , LOT           NVARCHAR(10) NOT NULL
       , ID            NVARCHAR(18) NOT NULL
       , QTY           INT          NOT NULL
       , QtyMoved      INT          NOT NULL
       , QtyInPickLOC  INT          NOT NULL
       , Priority      NVARCHAR(5)
       , UOM           NVARCHAR(10) NOT NULL
       , PACKKEY       NVARCHAR(10) NOT NULL
      )

      CREATE TABLE #TempSKUxLOC
      (
         ROWREF                INT          IDENTITY(1, 1) NOT NULL PRIMARY KEY
       , ReplenishmentPriority NVARCHAR(5)  NOT NULL
       , ReplenishmentSeverity INT          NOT NULL
       , StorerKey             NVARCHAR(15) NOT NULL
       , SKU                   NVARCHAR(20) NOT NULL
       , LOC                   NVARCHAR(10)
       , ReplenishmentCasecnt  INT          NOT NULL
      )

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         DECLARE @c_CurrentSKU                 NVARCHAR(20)
               , @c_CurrentStorer              NVARCHAR(15)
               , @c_CurrentLOC                 NVARCHAR(10)
               , @c_CurrentPriority            NVARCHAR(5)
               , @n_CurrentFullCase            INT
               , @n_CurrentSeverity            INT
               , @c_FromLOC                    NVARCHAR(10)
               , @c_fromlot                    NVARCHAR(10)
               , @c_fromid                     NVARCHAR(18)
               , @n_FromQty                    INT
               , @n_remainingqty               INT
               , @n_PossibleCases              INT
               , @n_remainingcases             INT
               , @n_OnHandQty                  INT
               , @n_fromcases                  INT
               , @c_ReplenishmentKey           NVARCHAR(10)
               , @n_numberofrecs               INT
               , @n_limitrecs                  INT
               , @c_fromlot2                   NVARCHAR(10)
               , @b_DoneCheckOverAllocatedLots INT
               , @n_SKULocAvailableQty         INT

         SELECT @c_CurrentSKU = SPACE(20)
              , @c_CurrentStorer = SPACE(15)
              , @c_CurrentLOC = SPACE(10)
              , @c_CurrentPriority = SPACE(5)
              , @n_CurrentFullCase = 0
              , @n_CurrentSeverity = 9999999
              , @n_FromQty = 0
              , @n_remainingqty = 0
              , @n_PossibleCases = 0
              , @n_remainingcases = 0
              , @n_fromcases = 0
              , @n_numberofrecs = 0
              , @n_limitrecs = 5

         /* Make a temp version of SKUxLOC */
         --      SELECT ReplenishmentPriority, 
         --             ReplenishmentSeverity,StorerKey,
         --             SKU, LOC, ReplenishmentCasecnt
         --      INTO #TempSKUxLOC
         --      FROM SKUxLOC (NOLOCK)
         --      WHERE 1=2

         IF (@c_zone02 = 'ALL')
         BEGIN
            INSERT #TempSKUxLOC
            SELECT DISTINCT SKUxLOC.ReplenishmentPriority
                          , ReplenishmentSeverity = CASE WHEN PACK.CaseCnt > 0 THEN
                                                            FLOOR((CONVERT(REAL, QtyLocationLimit)
                                                                   - (CONVERT(REAL, SKUxLOC.Qty)
                                                                      - CONVERT(REAL, SKUxLOC.QtyPicked)
                                                                      - CONVERT(REAL, SKUxLOC.QtyAllocated)))
                                                                  / CONVERT(REAL, PACK.CaseCnt))
                                                         ELSE
                                                            QtyLocationLimit
                                                            - (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated)) END
                          , SKUxLOC.StorerKey
                          , SKUxLOC.Sku
                          , SKUxLOC.Loc
                          , ReplenishmentCasecnt = CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt
                                                        ELSE 1 END
            FROM SKUxLOC (NOLOCK)
            JOIN LOC (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
            JOIN SKU (NOLOCK) ON SKUxLOC.StorerKey = SKU.StorerKey AND SKUxLOC.Sku = SKU.Sku
            JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
            JOIN (  SELECT SKUxLOC.StorerKey
                         , SKUxLOC.Sku
                         , SKUxLOC.Loc
                    FROM SKUxLOC (NOLOCK)
                    JOIN LOC (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
                    WHERE SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0
                    AND   SKUxLOC.LocationType NOT IN ( 'PICK', 'CASE' )
                    AND   (SKUxLOC.StorerKey = @c_StorerKey OR @c_StorerKey = 'ALL')
                    AND   LOC.Facility = @c_zone01
                    AND   LOC.LocationFlag NOT IN ( 'DAMAGE', 'HOLD' )) AS SL ON  SL.StorerKey = SKUxLOC.StorerKey
                                                                              AND SL.Sku = SKUxLOC.Sku
            WHERE LOC.LocationFlag NOT IN ( 'DAMAGE', 'HOLD' )
            AND   (SKUxLOC.LocationType = 'PICK' OR SKUxLOC.LocationType = 'CASE')
            AND   (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum)
            AND   LOC.Facility = @c_zone01
            AND   (SKUxLOC.StorerKey = @c_StorerKey OR @c_StorerKey = 'ALL')
         -- AND  SKUxLOC.SKu = '272857555XL'

         END
         ELSE
         BEGIN
            INSERT #TempSKUxLOC
            SELECT DISTINCT SKUxLOC.ReplenishmentPriority
                          , ReplenishmentSeverity = CASE WHEN PACK.CaseCnt > 0 THEN
                                                            FLOOR((CONVERT(REAL, QtyLocationLimit)
                                                                   - (CONVERT(REAL, SKUxLOC.Qty)
                                                                      - CONVERT(REAL, SKUxLOC.QtyPicked)
                                                                      - CONVERT(REAL, SKUxLOC.QtyAllocated)))
                                                                  / CONVERT(REAL, PACK.CaseCnt))
                                                         ELSE
                                                            QtyLocationLimit
                                                            - (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated)) END
                          , SKUxLOC.StorerKey
                          , SKUxLOC.Sku
                          , SKUxLOC.Loc
                          , ReplenishmentCasecnt = CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt
                                                        ELSE 1 END
            FROM SKUxLOC (NOLOCK)
            JOIN LOC (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
            JOIN SKU (NOLOCK) ON SKUxLOC.StorerKey = SKU.StorerKey AND SKUxLOC.Sku = SKU.Sku
            JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
            JOIN (  SELECT SKUxLOC.StorerKey
                         , SKUxLOC.Sku
                         , SKUxLOC.Loc
                    FROM SKUxLOC (NOLOCK)
                    JOIN LOC (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
                    WHERE SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0
                    AND   SKUxLOC.LocationType NOT IN ( 'PICK', 'CASE' )
                    AND   (SKUxLOC.StorerKey = @c_StorerKey OR @c_StorerKey = 'ALL')
                    AND   LOC.Facility = @c_zone01
                    AND   LOC.LocationFlag NOT IN ( 'DAMAGE', 'HOLD' )) AS SL ON  SL.StorerKey = SKUxLOC.StorerKey
                                                                              AND SL.Sku = SKUxLOC.Sku
            WHERE LOC.LocationFlag NOT IN ( 'DAMAGE', 'HOLD' )
            AND   (SKUxLOC.LocationType = 'PICK' OR SKUxLOC.LocationType = 'CASE')
            AND   (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum)
            AND   LOC.Facility = @c_zone01
            AND   LOC.PutawayZone IN ( @c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08
                                     , @c_zone09, @c_zone10, @c_zone11, @c_zone12 )
            AND   (SKUxLOC.StorerKey = @c_StorerKey OR @c_StorerKey = 'ALL')
         END
         IF @b_debug = 1
         BEGIN
            SELECT 'TEMPSKUxLOC table'
            SELECT *
            FROM #TempSKUxLOC (NOLOCK)
            ORDER BY ReplenishmentPriority
                   , ReplenishmentSeverity DESC
                   , StorerKey
                   , SKU
                   , LOC
         END

         -- SELECT @n_starttcnt=@@TRANCOUNT 
         BEGIN TRANSACTION
         WHILE (1 = 1) -- while 1
         BEGIN
            SELECT TOP 1 @c_CurrentPriority = ReplenishmentPriority
            FROM #TempSKUxLOC
            WHERE ReplenishmentPriority > @c_CurrentPriority AND ReplenishmentCasecnt > 0
            ORDER BY ReplenishmentPriority
            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END
            IF @b_debug = 1
            BEGIN
               PRINT 'Working on @c_CurrentPriority:' + dbo.fnc_RTRIM(@c_CurrentPriority)
            END
            /* Loop through SKUxLOC for the currentSKU, current storer */
            /* to pickup the next severity */
            SELECT @n_CurrentSeverity = 999999999
            WHILE (1 = 1) -- while 2
            BEGIN
               SELECT TOP 1 @n_CurrentSeverity = ReplenishmentSeverity
               FROM #TempSKUxLOC
               WHERE ReplenishmentSeverity < @n_CurrentSeverity
               AND   ReplenishmentPriority = @c_CurrentPriority
               AND   ReplenishmentCasecnt > 0
               ORDER BY ReplenishmentSeverity DESC
               IF @@ROWCOUNT = 0
               BEGIN
                  BREAK
               END
               IF @b_debug = 1
               BEGIN
                  PRINT 'Working on @n_CurrentSeverity:' + dbo.fnc_RTRIM(@n_CurrentSeverity)
               END

               /* Now - for this priority, this severity - find the next storer row */
               /* that matches */
               SELECT @c_CurrentSKU = SPACE(20)
                    , @c_CurrentStorer = SPACE(15)
               WHILE (1 = 1) -- while 3
               BEGIN
                  SELECT TOP 1 @c_CurrentStorer = StorerKey
                  FROM #TempSKUxLOC
                  WHERE StorerKey > @c_CurrentStorer
                  AND   ReplenishmentSeverity = @n_CurrentSeverity
                  AND   ReplenishmentPriority = @c_CurrentPriority
                  ORDER BY StorerKey

                  IF @@ROWCOUNT = 0
                  BEGIN
                     BREAK
                  END
                  IF @b_debug = 1
                  BEGIN
                     PRINT 'Working on @c_CurrentStorer:' + dbo.fnc_RTRIM(@c_CurrentStorer)
                  END
                  /* Now - for this priority, this severity - find the next SKU row */
                  /* that matches */


                  SELECT @c_CurrentSKU = SPACE(20)
                  WHILE (1 = 1) -- while 4
                  BEGIN
                     SELECT TOP 1 @c_CurrentSKU = SKU
                     FROM #TempSKUxLOC
                     WHERE SKU > @c_CurrentSKU
                     AND   StorerKey = @c_CurrentStorer
                     AND   ReplenishmentSeverity = @n_CurrentSeverity
                     AND   ReplenishmentPriority = @c_CurrentPriority
                     ORDER BY SKU
                     IF @@ROWCOUNT = 0
                     BEGIN
                        BREAK
                     END

                     IF @b_debug = 1
                     BEGIN
                        PRINT 'Working on @c_CurrentSKU:' + dbo.fnc_RTRIM(@c_CurrentSKU)
                     END

                     SELECT @c_CurrentLOC = SPACE(10)
                     WHILE (1 = 1) -- while 4
                     BEGIN
                        SELECT TOP 1 @c_CurrentStorer = StorerKey
                                   , @c_CurrentSKU = SKU
                                   , @c_CurrentLOC = LOC
                                   , @n_CurrentFullCase = ReplenishmentCasecnt
                        FROM #TempSKUxLOC
                        WHERE LOC > @c_CurrentLOC
                        AND   SKU = @c_CurrentSKU
                        AND   StorerKey = @c_CurrentStorer
                        AND   ReplenishmentSeverity = @n_CurrentSeverity
                        AND   ReplenishmentPriority = @c_CurrentPriority
                        ORDER BY LOC

                        IF @@ROWCOUNT = 0
                        BEGIN
                           BREAK
                        END

                        IF @b_debug = 1
                        BEGIN
                           PRINT 'Working on @c_CurrentLOC:' + dbo.fnc_RTRIM(@c_CurrentLOC)
                        END

                        /* We now have a pickLocation that needs to be replenished! */
                        /* Figure out which Locations in the warehouse to pull this product from */
                        /* End figure out which Locations in the warehouse to pull this product from */
                        SELECT @c_FromLOC = SPACE(10)
                             , @c_fromlot = SPACE(10)
                             , @c_fromid = SPACE(18)
                             , @n_FromQty = 0
                             , @n_PossibleCases = 0
                             , @n_remainingqty = @n_CurrentSeverity * @n_CurrentFullCase
                             , @n_remainingcases = @n_CurrentSeverity
                             , @c_fromlot2 = SPACE(10)
                             , @b_DoneCheckOverAllocatedLots = 0

                        DECLARE @c_uniquekey  NVARCHAR(40)
                              , @c_uniquekey2 NVARCHAR(40)

                        SELECT @c_uniquekey = N''
                             , @c_uniquekey2 = N''

                        SELECT TOP 1 @c_fromlot2 = LOTxLOCxID.Lot
                        FROM LOTxLOCxID (NOLOCK)
                           , LOC (NOLOCK)
                           , LOTATTRIBUTE (NOLOCK)
                           , LOT (NOLOCK)
                        WHERE LOTxLOCxID.Lot > @c_fromlot2
                        AND   LOTxLOCxID.StorerKey = @c_CurrentStorer
                        AND   LOTxLOCxID.Sku = @c_CurrentSKU
                        AND   LOTxLOCxID.Loc = LOC.Loc
                        AND   LOC.LocationFlag <> "DAMAGE"
                        AND   LOC.LocationFlag <> "HOLD"
                        AND   LOC.Status <> "HOLD"
                        AND   ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - LOTxLOCxID.Qty) > 0
                        AND   LOTxLOCxID.Loc = @c_CurrentLOC
                        AND   LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
                        AND   LOTxLOCxID.StorerKey = LOTATTRIBUTE.StorerKey
                        AND   LOTxLOCxID.Sku = LOTATTRIBUTE.Sku
                        AND   LOTxLOCxID.Lot = LOT.Lot
                        AND   LOT.Status <> "HOLD"
                        AND   LOC.Facility = @c_zone01
                        AND   LOTATTRIBUTE.Lottable02 NOT IN (  SELECT CODELKUP.Code
                                                                FROM CODELKUP
                                                                WHERE LISTNAME = 'GRADE_B' )
                        ORDER BY LOTxLOCxID.Lot

                        IF @@ROWCOUNT = 0
                        BEGIN

                           SELECT TOP 1 @c_fromlot = LOTxLOCxID.Lot
                                      , @c_FromLOC = LOTxLOCxID.Loc
                                      , @c_fromid = LOTxLOCxID.Id
                                      , @n_OnHandQty = LOTxLOCxID.Qty
                                                       - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)
                                      , @c_uniquekey2 = CASE LOC.LocationHandling
                                                             WHEN '2' THEN '05'
                                                             WHEN '1' THEN '10'
                                                             WHEN '9' THEN '15'
                                                             ELSE '99' END
                                                        + RIGHT(dbo.fnc_RTRIM(
                                                                   '000000000000000000'
                                                                   + CAST(LOTxLOCxID.Qty AS NVARCHAR(18))), 18)
                                                        + LOTxLOCxID.Loc + LOTxLOCxID.Lot + LOTxLOCxID.Id
                           FROM LOTxLOCxID (NOLOCK)
                           JOIN LOC (NOLOCK) ON  (LOTxLOCxID.Loc = LOC.Loc)
                                             AND (LOC.LocationFlag <> "DAMAGE")
                                             AND (LOC.LocationFlag <> "HOLD")
                                             --       AND (LOC.LocationType <> "BBA") 
                                             AND (LOC.Status <> "HOLD")
                           JOIN SKUxLOC (NOLOCK) ON  (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey)
                                                 AND (LOTxLOCxID.Sku = SKUxLOC.Sku)
                                                 AND (LOTxLOCxID.Loc = SKUxLOC.Loc)
                                                 AND (SKUxLOC.LocationType <> "CASE")
                                                 AND (SKUxLOC.LocationType <> "PICK")
                                                 AND (SKUxLOC.QtyExpected = 0)
                           JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.Id) AND (ID.Status <> "HOLD")
                           JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot) AND (LOT.Status <> "HOLD")
                           JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.Lot = LOT.Lot
                           WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND   LOTxLOCxID.Sku = @c_CurrentSKU
                           AND   LOTxLOCxID.Loc <> @c_CurrentLOC
                           AND   LOC.Facility = @c_zone01
                           AND   LOTxLOCxID.Lot = @c_fromlot2
                           AND   (LOTxLOCxID.QtyExpected = 0)
                           AND   (LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)) > 0
                           AND   NOT EXISTS (  SELECT 1
                                               FROM CODELKUP (NOLOCK)
                                               WHERE CODELKUP.Code = LOTATTRIBUTE.Lottable02
                                               AND   CODELKUP.LISTNAME = 'GRADE_B')
                           AND   NOT EXISTS (  SELECT 1
                                               FROM #REPLENISHMENT
                                               WHERE #REPLENISHMENT.LOT = LOTxLOCxID.Lot
                                               AND   #REPLENISHMENT.FROMLOC = LOTxLOCxID.Loc
                                               AND   #REPLENISHMENT.ID = LOTxLOCxID.Id
                                               GROUP BY #REPLENISHMENT.LOT
                                                      , #REPLENISHMENT.FROMLOC
                                                      , #REPLENISHMENT.ID
                                               HAVING (LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked))
                                                      - SUM(#REPLENISHMENT.QTY) <= 0)
                           ORDER BY CASE LOC.LocationType
                                         WHEN "BBA" THEN '05'
                                         ELSE '99' END
                                  , CASE LOC.LocationHandling
                                         WHEN '2' THEN '05'
                                         WHEN '1' THEN '10'
                                         WHEN '9' THEN '15'
                                         ELSE '99' END
                                  , LOTxLOCxID.Qty
                                  , LOTxLOCxID.Loc
                                  , LOTxLOCxID.Lot
                                  , LOTxLOCxID.Id DESC


                           IF @@ROWCOUNT > 0
                           BEGIN
                              GOTO GET_REPLENISH_RECORD
                           END
                        END

                        WHILE (1 = 1 AND @n_remainingqty > 0) -- while 5
                        BEGIN

                           SELECT TOP 1 @c_fromlot = LOTxLOCxID.Lot
                                      , @c_FromLOC = LOTxLOCxID.Loc
                                      , @c_fromid = LOTxLOCxID.Id
                                      , @n_OnHandQty = LOTxLOCxID.Qty
                                                       - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)
                                      , @c_uniquekey = CASE LOC.LocationHandling
                                                            WHEN '2' THEN '05'
                                                            WHEN '1' THEN '10'
                                                            WHEN '9' THEN '15'
                                                            ELSE '99' END
                                                       + RIGHT(dbo.fnc_RTRIM(
                                                                  '000000000000000000'
                                                                  + CAST(LOTxLOCxID.Qty AS NVARCHAR(18))), 18)
                                                       + LOTxLOCxID.Loc + LOTxLOCxID.Lot
                           FROM LOTxLOCxID (NOLOCK)
                           JOIN LOC (NOLOCK) ON  (LOTxLOCxID.Loc = LOC.Loc)
                                             AND (LOC.LocationFlag <> "DAMAGE")
                                             AND (LOC.LocationFlag <> "HOLD")
                                             -- AND (LOC.LocationType <> "BBA") 
                                             AND (LOC.Status <> "HOLD")
                           JOIN SKUxLOC (NOLOCK) ON  (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey)
                                                 AND (LOTxLOCxID.Sku = SKUxLOC.Sku)
                                                 AND (LOTxLOCxID.Loc = SKUxLOC.Loc)
                                                 AND (SKUxLOC.LocationType <> "CASE")
                                                 AND (SKUxLOC.LocationType <> "PICK")
                                                 AND (SKUxLOC.QtyExpected = 0)
                           JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.Id) AND (ID.Status <> "HOLD")
                           JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot) AND (LOT.Status <> "HOLD")
                           JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.Lot = LOT.Lot
                           WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND   LOTxLOCxID.Sku = @c_CurrentSKU
                           AND   LOTxLOCxID.Loc <> @c_CurrentLOC
                           AND   LOC.Facility = @c_zone01
                           AND   (LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)) > 0
                           AND   (LOTxLOCxID.QtyExpected = 0)
                           AND   NOT EXISTS (  SELECT 1
                                               FROM CODELKUP (NOLOCK)
                                               WHERE CODELKUP.Code = LOTATTRIBUTE.Lottable02
                                               AND   CODELKUP.LISTNAME = 'GRADE_B')
                           AND   (   (  (CASE LOC.LocationHandling
                                              WHEN '2' THEN '05'
                                              WHEN '1' THEN '10'
                                              WHEN '9' THEN '15'
                                              ELSE '99' END
                                         +   RIGHT(dbo.fnc_RTRIM('000000000000000000' + CAST(LOTxLOCxID.Qty AS NVARCHAR(18))), 18)
                                         +   LOTxLOCxID.Loc + LOTxLOCxID.Lot >= @c_uniquekey
                                     AND   LOTxLOCxID.Id < @c_fromid)
                                     OR (CASE LOC.LocationHandling
                                              WHEN '2' THEN '05'
                                              WHEN '1' THEN '10'
                                              WHEN '9' THEN '15'
                                              ELSE '99' END
                                         + RIGHT(dbo.fnc_RTRIM('000000000000000000' + CAST(LOTxLOCxID.Qty AS NVARCHAR(18))), 18)
                                         + LOTxLOCxID.Loc + LOTxLOCxID.Lot > @c_uniquekey))
                                 AND (CASE LOC.LocationHandling
                                           WHEN '2' THEN '05'
                                           WHEN '1' THEN '10'
                                           WHEN '9' THEN '15'
                                           ELSE '99' END
                                      + RIGHT(dbo.fnc_RTRIM('000000000000000000' + CAST(LOTxLOCxID.Qty AS NVARCHAR(18))), 18)
                                      + LOTxLOCxID.Loc + LOTxLOCxID.Lot + LOTxLOCxID.Id <> @c_uniquekey2))
                           AND   NOT EXISTS (  SELECT 1
                                               FROM #REPLENISHMENT
                                               WHERE #REPLENISHMENT.LOT = LOTxLOCxID.Lot
                                               AND   #REPLENISHMENT.FROMLOC = LOTxLOCxID.Loc
                                               AND   #REPLENISHMENT.ID = LOTxLOCxID.Id
                                               GROUP BY #REPLENISHMENT.LOT
                                                      , #REPLENISHMENT.FROMLOC
                                                      , #REPLENISHMENT.ID
                                               HAVING (LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked))
                                                      - SUM(#REPLENISHMENT.QTY) <= 0)
                           ORDER BY CASE LOC.LocationType
                                         WHEN "BBA" THEN '05'
                                         ELSE '99' END
                                  , CASE LOC.LocationHandling
                                         WHEN '2' THEN '05'
                                         WHEN '1' THEN '10'
                                         WHEN '9' THEN '15'
                                         ELSE '99' END
                                  , LOTxLOCxID.Qty
                                  , LOTxLOCxID.Loc
                                  , LOTxLOCxID.Lot
                                  , LOTxLOCxID.Id DESC



                           IF @@ROWCOUNT = 0
                           BEGIN
                              IF @b_debug = 1
                                 SELECT 'Not Lot Available! SKU= ' + @c_CurrentSKU + ' LOC=' + @c_CurrentLOC
                              BREAK
                           END
                           ELSE
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Lot picked from LOTxLOCxID'
                                      , @c_fromlot
                              END
                           END

                           IF @b_debug = 1
                           BEGIN

                              SELECT LOT
                                   , FROMLOC
                                   , ID
                                   , @n_OnHandQty - SUM(#REPLENISHMENT.QTY)
                                   , @n_OnHandQty onhandqty
                                   , SUM(#REPLENISHMENT.QTY) replqty
                              FROM #REPLENISHMENT
                              WHERE #REPLENISHMENT.LOT = @c_fromlot
                              AND   #REPLENISHMENT.FROMLOC = @c_FromLOC
                              AND   #REPLENISHMENT.ID = @c_fromid
                              GROUP BY #REPLENISHMENT.LOT
                                     , #REPLENISHMENT.FROMLOC
                                     , #REPLENISHMENT.ID
                           END
                           IF @b_debug = 1
                           BEGIN
                              SELECT 'Selected Lot'
                                   , @c_fromlot
                           END

                           GET_REPLENISH_RECORD:

                           SELECT @n_OnHandQty = @n_OnHandQty - SUM(#REPLENISHMENT.QTY)
                           FROM #REPLENISHMENT
                           WHERE #REPLENISHMENT.LOT = @c_fromlot
                           AND   #REPLENISHMENT.FROMLOC = @c_FromLOC
                           AND   #REPLENISHMENT.ID = @c_fromid
                           GROUP BY #REPLENISHMENT.LOT
                                  , #REPLENISHMENT.FROMLOC
                                  , #REPLENISHMENT.ID

                           /* How many cases can I get from this record? */
                           SELECT @n_PossibleCases = FLOOR(@n_OnHandQty / @n_CurrentFullCase)

                           IF @b_debug = 1
                           BEGIN
                              SELECT '@n_OnHandQty' = @n_OnHandQty
                                   , '@n_RemainingQty' = @n_remainingqty
                              SELECT '@n_possiblecases' = @n_PossibleCases
                                   , '@n_currentFullCase' = @n_CurrentFullCase
                           END
                           /* How many do we take? */
                           IF @n_OnHandQty > @n_remainingqty
                           BEGIN
                              -- Modify by SHONG for full carton only
                              -- Take Full Case if the qty need to replenish < carton
                              IF @n_OnHandQty >= @n_CurrentFullCase AND @n_remainingqty <= @n_CurrentFullCase
                              BEGIN
                                 SET @n_FromQty = @n_CurrentFullCase
                                 SELECT @n_remainingqty = 0
                              END
                              ELSE IF @n_OnHandQty >= @n_CurrentFullCase AND @n_remainingqty > @n_CurrentFullCase
                              BEGIN
                                 SELECT @n_PossibleCases = FLOOR(@n_remainingqty / @n_CurrentFullCase)
                                 IF  (@n_remainingqty / @n_CurrentFullCase) > @n_PossibleCases
                                 AND (@n_PossibleCases * @n_CurrentFullCase) < @n_remainingqty
                                 BEGIN
                                    -- take one more case
                                    SET @n_PossibleCases = @n_PossibleCases + 1
                                 END

                                 SELECT @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase)

                                 SELECT @n_remainingqty = 0
                              END
                              ELSE
                              BEGIN

                                 -- User want to take all the remaining Qty in the Bulk
                                 -- Location if it less then 1 Carton 
                                 -- SELECT @n_FromQty = @n_RemainingQty
                                 IF @n_OnHandQty <= @n_CurrentFullCase
                                 BEGIN
                                    SELECT @n_FromQty = @n_OnHandQty
                                 END
                                 ELSE
                                 BEGIN
                                    SELECT @n_FromQty = @n_remainingqty
                                 END
                                 SELECT @n_remainingqty = 0
                              END
                           END
                           ELSE
                           BEGIN
                              -- Modify by shong for full carton only

                              IF @n_OnHandQty > @n_CurrentFullCase
                              BEGIN
                                 /* Total Carton On Hand > Total Carton to take and With Loose Qty > 0 ? */
                                 IF  (@n_OnHandQty / @n_CurrentFullCase) > @n_PossibleCases
                                 AND (@n_PossibleCases * @n_CurrentFullCase) < @n_FromQty
                                 BEGIN
                                    -- take one more case
                                    SET @n_PossibleCases = @n_PossibleCases + 1
                                 END

                                 SELECT @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase)
                              END
                              ELSE
                              BEGIN

                                 IF @n_OnHandQty = (  SELECT SUM(Qty - QtyAllocated - QtyPicked)
                                                      FROM LOTxLOCxID (NOLOCK)
                                                      WHERE Lot = @c_fromlot AND Loc = @c_FromLOC AND Id = @c_fromid)
                                 BEGIN
                                    SELECT @n_FromQty = @n_OnHandQty
                                 END
                                 ELSE
                                 BEGIN
                                    SELECT @n_FromQty = 0
                                 END
                              END

                              SELECT @n_remainingqty = @n_remainingqty - @n_FromQty

                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Checking possible cases AND current full case available - @n_RemainingQty > @n_FromQty'
                                 SELECT '@n_possiblecases' = @n_PossibleCases
                                      , '@n_currentFullCase' = @n_CurrentFullCase
                                 SELECT '@n_FromQty' = @n_FromQty
                              END
                           END

                           IF @n_FromQty > 0
                           BEGIN
                              SELECT @c_Packkey = PACK.PackKey
                                   , @c_UOM = PACK.PackUOM3
                              FROM SKU (NOLOCK)
                                 , PACK (NOLOCK)
                              WHERE SKU.PACKKey = PACK.PackKey
                              AND   SKU.StorerKey = @c_CurrentStorer
                              AND   SKU.Sku = @c_CurrentSKU
                              -- print 'before insert into replenishment'
                              -- SELECT @n_fromqty 'fromqty', @n_possiblecases 'possiblecases', @n_remainingqty 'remainingqty'
                              IF @n_continue = 1 OR @n_continue = 2
                              BEGIN
                                 INSERT #REPLENISHMENT (StorerKey, SKU, FROMLOC, ToLOC, LOT, ID, QTY, UOM, PACKKEY
                                                      , Priority, QtyMoved, QtyInPickLOC)
                                 VALUES (@c_CurrentStorer, @c_CurrentSKU, @c_FromLOC, @c_CurrentLOC, @c_fromlot
                                       , @c_fromid, @n_FromQty, @c_UOM, @c_Packkey, @c_CurrentPriority, 0, 0)
                              END
                              SELECT @n_numberofrecs = @n_numberofrecs + 1
                           END -- if from qty > 0

                           IF @b_debug = 1
                           BEGIN
                              SELECT @c_CurrentSKU ' SKU'
                                   , @c_CurrentLOC 'LOC'
                                   , @c_CurrentPriority 'priority'
                                   , @n_CurrentFullCase 'full case'
                                   , @n_CurrentSeverity 'severity'
                              -- SELECT @n_FromQty 'qty', @c_FromLOC 'fromLOC', @c_fromlot 'from lot', @n_PossibleCases 'possible cases'
                              SELECT @n_remainingqty '@n_remainingqty'
                                   , @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
                                   , @c_fromlot 'from lot'
                                   , @c_fromid
                           END

                        END -- SCAN LOT FOR LOT
                     END -- FOR LOC
                  END -- FOR SKU

               END -- FOR STORER
            END -- FOR SEVERITY
         END -- (WHILE 1=1 on SKUxLOC FOR PRIORITY )
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         /* Update the column QtyInPickLOC in the Replenishment Table */
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            UPDATE #REPLENISHMENT
            SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked
            FROM SKUxLOC (NOLOCK)
            WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey
            AND   #REPLENISHMENT.SKU = SKUxLOC.Sku
            AND   #REPLENISHMENT.ToLOC = SKUxLOC.Loc
         END
      END


      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SET @n_Rowcnt = 0
         SELECT @n_Rowcnt = COUNT(1)
         FROM #REPLENISHMENT R

         IF ISNULL(@n_Rowcnt, 0) > 0
         BEGIN
            -- Get Key by BATCH
            DECLARE @b_success INT
                  , @n_err     INT
                  , @c_errmsg  NVARCHAR(255)

            BEGIN TRAN

            EXECUTE nspg_GetKey 'REPLENISHKEY'
                              , 10
                              , @c_ReplenishmentKey OUTPUT
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
                              , 0
                              , @n_Rowcnt
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                    , @n_err = 63529
               SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                                  + N': Fail to get REPLENISHKEY. (isp_RPT_REPL_REPLEN_008)' + N' ( '
                                  + N' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + N' ) '
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
         END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         /* Insert Into Replenishment Table Now */

         SET @n_ReplenishmentKey = CAST(@c_ReplenishmentKey AS INT)

         BEGIN TRAN
         DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT R.ROWREF
         FROM #REPLENISHMENT R
         OPEN CUR1

         FETCH NEXT FROM CUR1
         INTO @n_ROWREF
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            SET @c_ReplenishmentKey = dbo.fnc_RTRIM(dbo.fnc_LTRIM(CONVERT(CHAR(10), @n_ReplenishmentKey)))
            SET @c_ReplenishmentKey = RIGHT(dbo.fnc_RTRIM(REPLICATE('0', 10) + @c_ReplenishmentKey), 10)

            INSERT REPLENISHMENT (ReplenishmentGroup, ReplenishmentKey, Storerkey, Sku, FromLoc, ToLoc, Lot, Id, Qty
                                , UOM, PackKey, Confirmed)
            SELECT 'IDS'
                 , @c_ReplenishmentKey
                 , R.StorerKey
                 , R.SKU
                 , R.FROMLOC
                 , R.ToLOC
                 , R.LOT
                 , R.ID
                 , R.QTY
                 , R.UOM
                 , R.PACKKEY
                 , 'N'
            FROM #REPLENISHMENT R (NOLOCK)
            WHERE R.ROWREF = @n_ROWREF
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                    , @n_err = 63524
               SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                                  + N': Insert into Replenishment table failed. (isp_RPT_REPL_REPLEN_008)' + N' ( '
                                  + N' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + N' ) '
            END

            SET @n_ReplenishmentKey = @n_ReplenishmentKey + 1

            FETCH NEXT FROM CUR1
            INTO @n_ROWREF
         END -- While
         CLOSE CUR1
         DEALLOCATE CUR1

         COMMIT TRAN
      END


      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END

      WHILE @@TRANCOUNT < @n_starttcnt
      BEGIN
         BEGIN TRAN
      END


      -- End Insert Replenishment
      IF @n_continue = 3 -- Error Occured - Process AND Return
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_REPL_REPLEN_008'
         RAISERROR(@c_errmsg, 16, 1) WITH SETERROR
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
   END

   IF @c_Functype = 'G'
   BEGIN
      GOTO QUIT_SP
   END

   IF (@c_zone02 = 'ALL')
   BEGIN
      SELECT R.FromLoc
           , CASE WHEN ISNULL(CLR.Code, '') <> '' THEN SKU.ALTSKU
                  ELSE R.Id END AS ID
           , R.ToLoc
           , R.Sku
           , R.Qty
           , R.Storerkey
           , R.Lot
           , R.PackKey
           , CASE WHEN ISNULL(CLR.Code, '') <> '' THEN
                     RTRIM(ISNULL(SKU.Style, '')) + ' ' + RTRIM(ISNULL(SKU.Color, '')) + ' '
                     + RTRIM(ISNULL(SKU.Size, ''))
                  ELSE SKU.DESCR END AS Descr
           , R.Priority
           , L1.PutawayZone
           , PACK.CaseCnt
           , PACK.PackUOM1
           , PACK.PackUOM3
           , R.ReplenishmentKey
           , (LT.Qty - LT.QtyAllocated - LT.QtyPicked) AS QtyOnHand
           , LA.Lottable02
           , [dbo].[fnc_ConvSFTimeZone](R.StorerKey, L1.Facility, LA.Lottable04) AS Lottable04   --GTZ01
           , [dbo].[fnc_ConvSFTimeZone](R.StorerKey, L1.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
      FROM REPLENISHMENT R (NOLOCK)
      JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.Storerkey
      JOIN LOC L1 (NOLOCK) ON L1.Loc = R.ToLoc
      JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      JOIN LOC L2 (NOLOCK) ON L2.Loc = R.FromLoc
      JOIN LOTxLOCxID LT (NOLOCK) ON LT.Lot = R.Lot AND LT.Loc = R.FromLoc AND LT.Id = R.Id
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LT.Sku = LA.Sku AND LT.StorerKey = LA.StorerKey AND LT.Lot = LA.Lot
      LEFT JOIN CODELKUP CLR (NOLOCK) ON (   R.Storerkey = CLR.Storerkey
                                         AND CLR.Code = 'CUSTOM_MAP_DESC_ID'
                                         AND CLR.LISTNAME = 'REPORTCFG'
                                         AND CLR.Long = 'RPT_REPL_REPLEN_008'
                                         AND ISNULL(CLR.Short, '') <> 'N')
      WHERE R.Confirmed = 'N'
      AND   L1.Facility = @c_zone01
      AND   (R.Storerkey = @c_StorerKey OR @c_StorerKey = 'ALL')
      AND   (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')
      ORDER BY L1.PutawayZone
             , R.Priority
   END
   ELSE
   BEGIN
      SELECT R.FromLoc
           , CASE WHEN ISNULL(CLR.Code, '') <> '' THEN SKU.ALTSKU
                  ELSE R.Id END AS ID
           , R.ToLoc
           , R.Sku
           , R.Qty
           , R.Storerkey
           , R.Lot
           , R.PackKey
           , CASE WHEN ISNULL(CLR.Code, '') <> '' THEN
                     RTRIM(ISNULL(SKU.Style, '')) + ' ' + RTRIM(ISNULL(SKU.Color, '')) + ' '
                     + RTRIM(ISNULL(SKU.Size, ''))
                  ELSE SKU.DESCR END AS Descr
           , R.Priority
           , L1.PutawayZone
           , PACK.CaseCnt
           , PACK.PackUOM1
           , PACK.PackUOM3
           , R.ReplenishmentKey
           , (LT.Qty - LT.QtyAllocated - LT.QtyPicked) AS QtyOnHand
           , LA.Lottable02
           , [dbo].[fnc_ConvSFTimeZone](R.StorerKey, L1.Facility, LA.Lottable04) AS Lottable04   --GTZ01
           , [dbo].[fnc_ConvSFTimeZone](R.StorerKey, L1.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
      FROM REPLENISHMENT R (NOLOCK)
      JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.Storerkey
      JOIN LOC L1 (NOLOCK) ON L1.Loc = R.ToLoc
      JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      JOIN LOC L2 (NOLOCK) ON L2.Loc = R.FromLoc
      JOIN LOTxLOCxID LT (NOLOCK) ON LT.Lot = R.Lot AND LT.Loc = R.FromLoc AND LT.Id = R.Id
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LT.Sku = LA.Sku AND LT.StorerKey = LA.StorerKey AND LT.Lot = LA.Lot
      LEFT JOIN CODELKUP CLR (NOLOCK) ON (   R.Storerkey = CLR.Storerkey
                                         AND CLR.Code = 'CUSTOM_MAP_DESC_ID'
                                         AND CLR.LISTNAME = 'REPORTCFG'
                                         AND CLR.Long = 'RPT_REPL_REPLEN_008'
                                         AND ISNULL(CLR.Short, '') <> 'N')
      WHERE R.Confirmed = 'N'
      AND   L1.Facility = @c_zone01
      AND   L1.PutawayZone IN ( @c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09
                              , @c_zone10, @c_zone11, @c_zone12 )
      AND   (R.Storerkey = @c_StorerKey OR @c_StorerKey = 'ALL')
      AND   (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')
      ORDER BY L1.PutawayZone
             , R.Priority
   END
   QUIT_SP:
END

GO