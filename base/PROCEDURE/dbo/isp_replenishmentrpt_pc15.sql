SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_ReplenishmentRpt_PC15                             */
/* Creation Date: 10-JUL-2013                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#:282150 - PNG Taiwan Replenishment Report                  */
/*        : modify from nsp_replenishmentrpt_pc08                          */
/*                                                                         */
/* Called By: Replenishment Report                                         */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 13-Sep-2013 YTWan    1.1   SOS#289072 - SK2 Taiwan (Wan01)              */
/*                            - Only Replenish when overallocate           */
/*                            - Not Replenish by Handling                  */
/* 05-MAR-2018 Wan02    1.2   WM - Add Functype                            */
/* 05-OCT-2018 CZTENG01 1.3   WM - Add ReplGrp                             */
/***************************************************************************/
CREATE PROC [dbo].[isp_ReplenishmentRpt_PC15]
               @c_zone01           NVARCHAR(10)
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
,              @c_storerkey        NVARCHAR(15) 
,              @c_ReplGrp          NVARCHAR(30) = 'ALL' --(CZTENG01)
,              @c_Functype         NCHAR(1) = ''        --(Wan02)  
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
   DECLARE @b_debug        INT 
         , @c_Packkey      NVARCHAR(10) 
         , @c_UOM          NVARCHAR(10)   
         , @n_FullPallet   INT
         , @n_PalletCnt    INT 

   SET @n_continue=1 
   SET @b_debug = 0

   IF @c_zone12 = '1'
   BEGIN
      SET @b_debug = CAST( @c_zone12 AS int)
      SET @c_zone12 = ''
   END

   --(Wan02) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
   
   IF @c_FuncType IN ( 'P' )                                     
   BEGIN
      GOTO QUIT_SP    
   END
   --(Wan02) - END

   DECLARE @c_priority  NVARCHAR(5)
   SELECT StorerKey
         ,SKU
         ,FromLOC      = LOC 
         ,ToLOC        = LOC 
         ,Lot
         ,Id
         ,Qty
         ,QtyMoved     = Qty 
         ,QtyInPickLOC = Qty 
         ,Priority     = @c_priority 
         ,UOM          = Lot 
         ,PackKey      = Lot 
   INTO #REPLENISHMENT
   FROM LOTXLOCXID (NOLOCK)
   WHERE 1 = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_CurrentSKU                  NVARCHAR(20)
            , @c_CurrentStorer               NVARCHAR(15)
            , @c_CurrentLoc                  NVARCHAR(10)
            , @c_CurrentPriority             NVARCHAR(5)
            , @n_currentfullcase             INT
            , @n_CurrentSeverity             INT
            , @c_FromLOC                 NVARCHAR(10)
            , @c_fromlot                     NVARCHAR(10)
            , @c_fromid                      NVARCHAR(18) 
            , @n_FromQty                     INT
            , @n_remainingqty                INT
            , @n_possiblecases               INT
            , @n_remainingcases              INT
            , @n_OnHandQty                   INT
            , @n_fromcases                   INT 
            , @c_ReplenishmentKey            NVARCHAR(10)
            , @n_numberofrecs                INT
            , @c_fromlot2                    NVARCHAR(10) 
            , @b_DoneCheckOverAllocatedLots  INT
            , @n_SKULOCavailableqty          INT 
            , @c_hostwhcode                  NVARCHAR(10) 
            , @c_overallocation              NVARCHAR(1)
      
            --(Wan01) - START
            , @n_ReplOverAlloc               INT
            , @n_ReplToMax                   INT
            , @n_ReplByPiece                 INT
            , @n_QtyExpected                 INT
            --(Wan01) - END
      SET @c_CurrentSKU       = ''
      SET @c_CurrentStorer    = ''
      SET @c_CurrentLoc       = ''
      SET @c_CurrentPriority  = ''
      SET @n_currentfullcase  = 0   
      SET @n_CurrentSeverity  = 9999999  
      SET @n_FromQty          = 0
      SET @n_remainingqty     = 0  
      SET @n_possiblecases    = 0 
      SET @n_remainingcases   = 0  
      SET @n_fromcases        = 0
      SET @n_numberofrecs     = 0 

      --(Wan01) - START
      SET @n_ReplOverAlloc    = 0
      SET @n_ReplToMax        = 0
      SET @n_ReplByPiece      = 0
      SET @n_QtyExpected      = 0
      --(Wan01) - END
      /* Make a temp version of SKUxLOC */
      SELECT ReplenishmentPriority
            ,ReplenishmentSeverity 
            ,StorerKey
            ,SKU
            ,LOC
            ,ReplenishmentCasecnt
            ,'N' AS Overallocation
            --(Wan01) - START
            , 0  AS QtyExpected
            --(Wan01) - END
      INTO #TempSKUxLOC
      FROM SKUxLOC (NOLOCK)
      WHERE 1=2

      INSERT #TempSKUxLOC
      SELECT ReplenishmentPriority
            ,ReplenishmentSeverity = CASE WHEN SUM(LOTxLOCxID.QtyExpected) > 0 
                                               AND SKUxLOC.QtyLocationMinimum < (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated))
                                          THEN SUM(LOTxLOCxID.QtyExpected)
                                          ELSE SKUxLOC.QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))
                                          END 
            ,SKUxLOC.StorerKey 
            ,SKUxLOC.SKU 
            ,SKUxLOC.LOC 
            ,ReplenishmentCasecnt
            ,OverAllocation = CASE WHEN SUM(LOTxLOCxID.QtyExpected) > 0 
                                        AND SKUxLOC.QtyLocationMinimum < (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated))   
                                   THEN 'Y'
                                   ELSE 'N' 
                                   END
            --(Wan01) - START
            ,QtyExpected = SUM(LOTxLOCxID.QtyExpected)
            --(Wan01) - END
      FROM SKUxLOC    WITH (NOLOCK)
      JOIN LOC        WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
      JOIN SKU        WITH (NOLOCK) ON (SKUxLOC.Storerkey = SKU.Storerkey) AND (SKUxLOC.Sku = SKU.Sku) 
      JOIN LOTxLOCxID WITH (NOLOCK) ON (SKUxLOC.Storerkey = LOTxLOCxID.Storerkey) AND (SKUxLOC.Sku = LOTxLOCxID.Sku) 
                                    AND(SKUxLOC.Loc = LOTxLOCxID.Loc)  
      WHERE (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') 
      AND   (SKUxLOC.LOCationtype = 'PICK' or SKUxLOC.LOCationtype = 'CASE')
      AND   LOC.FACILITY = @c_Zone01
      AND   (LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
      OR     @c_zone02 = 'ALL')
      GROUP BY SKUxLOC.ReplenishmentPriority 
             , SKUxLOC.StorerKey 
             , SKUxLOC.SKU 
             , SKUxLOC.LOC 
             , SKUxLOC.ReplenishmentCasecnt 
             , SKUxLOC.Qty 
             , SKUxLOC.QtyPicked 
             , SKUxLOC.QtyAllocated 
             , SKUxLOC.QtyLocationMinimum 
             , SKUxLOC.QtyLocationLimit
      HAVING SUM(LOTxLOCxID.QtyExpected) > 0 OR 
            (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )

      --(Wan01) - START
      --SET ROWCOUNT 0
      --/* Loop through SKUxLOC for the currentSKU, current storer */
      --/* to pickup the next severity */
      --SET @c_CurrentSKU = ''
      --SET @c_CurrentLoc = ''
      --WHILE (1=1)
      --BEGIN
      --   SET ROWCOUNT 1
      --   SELECT @c_CurrentStorer = StorerKey 
      --         ,@c_CurrentSKU = SKU 
      --         ,@c_CurrentLoc = LOC 
      --         ,@n_currentfullcase = ReplenishmentCasecnt 
      --         ,@n_CurrentSeverity = ReplenishmentSeverity 
      --         ,@c_overallocation  = OverAllocation
      --   FROM #TempSKUxLOC
      --   WHERE SKU > @c_CurrentSKU
      --   ORDER BY SKU

      --   IF @@ROWCOUNT = 0
      --   BEGIN
      --      SET ROWCOUNT 0
      --      BREAK
      --   END
      --   SET ROWCOUNT 0

      DECLARE CUR_SKUxLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT CurrentStorer = StorerKey 
            ,CurrentSKU = SKU 
            ,CurrentLoc = LOC 
            ,currentfullcase = ReplenishmentCasecnt 
            ,CurrentSeverity = ReplenishmentSeverity 
            ,OverAllocation
            ,QtyExpected
      FROM #TempSKUxLOC
      ORDER BY StorerKey
            ,  SKU

      OPEN CUR_SKUxLOC

      FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                    ,  @c_CurrentSKU 
                                    ,  @c_CurrentLoc
                                    ,  @n_currentfullcase
                                    ,  @n_CurrentSeverity
                                    ,  @c_OverAllocation
                                    ,  @n_QtyExpected
      WHILE @@Fetch_Status <> -1
      BEGIN
         SET @n_ReplOverAlloc    = 0
         SET @n_ReplByPiece      = 0
         SET @n_ReplToMax        = 0
   
         SELECT @n_ReplOverAlloc = 1
         FROM CODELKUP WITH (NOLOCK)
         WHERE ListName = 'RPLRPTPC15'
         AND   Code     = 'OVERALLOC'
         AND   Storerkey = @c_CurrentStorer

         IF @n_ReplOverAlloc = 1 AND @n_QtyExpected <= 0
         BEGIN
            GOTO FIND_NEXT_SKUxLOC
         END 

--         SELECT @n_ReplToMax = 1
--         FROM CODELKUP WITH (NOLOCK)
--         WHERE ListName = 'RPLRPTPC15'
--         AND   Code     = 'REPLTOMAX'
--         AND   Storerkey = @c_CurrentStorer

         SELECT @n_ReplByPiece = 1
         FROM CODELKUP WITH (NOLOCK)
         WHERE ListName = 'RPLRPTPC15'
         AND   Code     = 'REPLBYPIECE'
         AND   Storerkey = @c_CurrentStorer


      --(Wan01) - END

         /* We now have a pickLOCation that needs to be replenished! */
         /* Figure out which LOCations in the warehouse to pull this product from */
         /* End figure out which LOCations in the warehouse to pull this product from */
         SET @c_FromLOC = ''
         SET @c_fromlot = ''
         SET @c_fromid  = ''
         SET @n_FromQty = 0
         SET @n_possiblecases = 0  

          SET @n_Remainingqty  = @n_CurrentSeverity 

         SET @n_remainingcases = CASE WHEN @n_currentfullcase > 0 
                                      THEN @n_CurrentSeverity / @n_currentfullcase
                                      ELSE @n_CurrentSeverity
                                 END 
         SET @c_fromlot2 = ''
         SET @b_DoneCheckOverAllocatedLots = 0

         SELECT @c_hostwhcode = ISNULL(RTRIM(HostWHCode),'')
         FROM LOC WITH (NOLOCK)
         WHERE Loc = @c_CurrentLoc


         SELECT LOTxLOCxID.LOT
               ,'OVERALLOC' AS Overallocation
         INTO #TMP_OVERALLOC
         FROM LOTxLOCxID WITH (NOLOCK)
         JOIN LOC        WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.Loc) 
         JOIN LOT        WITH (NOLOCK) ON (LOTxLOCxID.LOT = LOT.Lot)  
         WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
         AND LOTxLOCxID.SKU = @c_CurrentSKU
         AND LOTxLOCxID.QtyExpected > 0 
         AND LOTxLOCxID.LOC = @c_CurrentLoc
         AND LOT.Status     = 'OK'          
         GROUP BY LOTxLOCxID.LOT   
         
         DECLARE LOT_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT LOTxLOCxID.LOT
         FROM LOTxLOCxID   WITH (NOLOCK)
         JOIN LOT          WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
         JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
         JOIN ID           WITH (NOLOCK) ON (LOTxLOCxID.ID  = ID.ID)
         JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.LOT = LOTATTRIBUTE.LOT)
         LEFT JOIN #TMP_OVERALLOC        ON (LOTxLOCxID.Lot = #TMP_OVERALLOC.Lot)
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
         GROUP BY LOTxLOCxID.LOT
               ,  ISNULL(#TMP_OVERALLOC.Overallocation,'')   
         ORDER BY CASE WHEN ISNULL(#TMP_OVERALLOC.Overallocation,'')='OVERALLOC' THEN 1 ELSE 2 END
                , MIN(ISNULL(LOTTABLE04, '1900-01-01'))
                , MIN(ISNULL(LOTTABLE05, '1900-01-01'))

         OPEN LOT_CUR

         FETCH NEXT FROM LOT_CUR INTO @c_FromLot 
         WHILE @@Fetch_Status <> -1 AND @n_remainingqty > 0 
         BEGIN
--(Wan01) - START
--            SET ROWCOUNT 0
--            SET @c_FromLOC = ''

--            DECLARE LOC_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
--            SELECT LOTxLOCxID.LOC
--            FROM LOTxLOCxID WITH (NOLOCK)
--            JOIN LOC        WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
--            WHERE LOT = @c_fromlot
--            AND LOTxLOCxID.LOC = LOC.LOC
--            AND StorerKey = @c_CurrentStorer
--            AND SKU = @c_CurrentSKU
--            AND LOC.LocationFlag <> 'DAMAGE'
--            AND LOC.LocationFlag <> 'HOLD'
--            AND LOC.Status <> 'HOLD'
--            AND LOTxLOCxID.qty - QtyPicked - QtyAllocated > 0
--            AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
--            AND LOTxLOCxID.LOC <> @c_CurrentLoc
--            AND LOC.Facility = @c_zone01
--            AND LOC.hostwhcode = @c_HostWHCode  
--            GROUP BY ISNULL(RTRIM(LOC.LogicalLocation),'')
--                  ,  LOTxLOCxID.LOC
--            ORDER BY SUM(LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated) 
--                  , ISNULL(RTRIM(LOC.LogicalLocation),'')
--                  , LOTxLOCxID.LOC
--
--            OPEN LOC_CUR 
--       
--            FETCH NEXT FROM LOC_CUR INTO @c_FromLOC 
--   
--            WHILE @@Fetch_Status <> -1 AND @n_remainingqty > 0 
--            BEGIN
--               SET ROWCOUNT 0
--               SET @c_fromid = replicate('Z',18)
--
--               WHILE (1=1 AND @n_remainingqty > 0)
--               BEGIN
--                  SET ROWCOUNT 1
--                  SELECT @c_fromid = LOTxLOCxID.ID
--                        ,@n_OnHandQty = LOTxLOCxID.QTY - QtyPicked - QtyAllocated
--                  FROM LOTxLOCxID WITH (NOLOCK)
--                  JOIN LOC        WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
--                  WHERE LOT = @c_fromlot
--                  AND LOTxLOCxID.LOC = @c_FromLOC
--                  AND id < @c_fromid
--                  AND StorerKey = @c_CurrentStorer
--                  AND SKU = @c_CurrentSKU
--                  AND LOC.LocationFlag <> 'DAMAGE'
--                  AND LOC.LocationFlag <> 'HOLD'
--                  AND LOC.Status <> 'HOLD'
--                  AND LOTxLOCxID.qty - QtyPicked - QtyAllocated > 0
--                  AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
--                  AND LOTxLOCxID.LOC <> @c_CurrentLoc
--                  AND LOC.Facility = @c_Zone01
--                  AND LOC.hostwhcode = @c_HostWHCode 
--                  ORDER BY LOTxLOCxID.ID DESC
--                     
--                  IF @@ROWCOUNT = 0
--                  BEGIN
--                     IF @b_debug = 1
--                     BEGIN
--                        SELECT 'Stop because No Pallet Found! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_FromLOC
--                        + ' From ID = ' + @c_fromid
--                     END
--                     SET ROWCOUNT 0
--                     -- GOTO FIND_NEXT_LOT -- SOS#129030
--                     GOTO FIND_NEXT_LOC -- SOS#129030
--                  END
--                  SET ROWCOUNT 0
--(Wan01) - END
            DECLARE INV_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT LOTxLOCxID.LOC
                  ,LOTxLOCxID.ID
                  , LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated 
            FROM LOTxLOCxID WITH (NOLOCK)
            JOIN LOC        WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
            WHERE LOT = @c_fromlot
            AND LOTxLOCxID.LOC = LOC.LOC
            AND LOTxLOCxID.StorerKey = @c_CurrentStorer
            AND LOTxLOCxID.SKU = @c_CurrentSKU
            AND LOC.LocationFlag <> 'DAMAGE'
            AND LOC.LocationFlag <> 'HOLD'
            AND LOC.Status <> 'HOLD'
            AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0
            AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
            AND LOTxLOCxID.LOC <> @c_CurrentLoc
            AND LOC.Facility = @c_zone01
            AND LOC.Hostwhcode = @c_Hostwhcode  
            ORDER BY LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated 
                  ,  ISNULL(RTRIM(LOC.LogicalLocation),'')
                  ,  LOTxLOCxID.LOC

            OPEN INV_CUR 
            
            FETCH NEXT FROM INV_CUR INTO @c_FromLOC   
                                       , @c_fromid 
                                       , @n_OnHandQty
            WHILE @@Fetch_Status <> -1 AND @n_remainingqty > 0 
            BEGIN

                  /* We have a cANDidate FROM record */
                  /* Verify that the cANDidate ID is not on HOLD */
                  /* We could have done this in the SQL statements above */
                  /* But that would have meant a 5-way join.             */
                  /* SQL SERVER seems to work best on a maximum of a     */
                  /* 4-way join.                                       */
                  IF EXISTS(SELECT 1 FROM ID WITH (NOLOCK) WHERE ID = @c_fromid AND STATUS = 'HOLD')
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Stop because ID Status = HOLD! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU + ' ID = ' + @c_fromid
                     END
                     --(Wan01) - START
                     GOTO FIND_NEXT_INV 
                     --  CONTINUE -- Should Try Another ID instead of Terminate
                     --(Wan01) - END
                     -- BREAK -- Get out of loop, so that next cANDidate can be evaluated
                  END
                  /* Verify that the from LOCation is not overalLOCated in SKUxLOC */
                  IF EXISTS(SELECT 1 FROM SKUxLOC WITH(NOLOCK)
                            WHERE StorerKey = @c_CurrentStorer
                            AND   Sku = @c_CurrentSKU
                            AND   Loc = @c_FromLOC
                            AND   QtyExpected > 0
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
                  IF EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)
                           WHERE StorerKey = @c_CurrentStorer
                           AND   Sku = @c_CurrentSKU
                           AND   Loc = @c_FromLOC
                           AND   LocationType = 'PICK'
                           )
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Stop because LOCation Type = PICK! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU
                     END
                     --(Wan01) - START
                     GOTO FIND_NEXT_INV 
                     --BREAK -- Get out of loop, so that next cANDidate can be evaluated
                     --(Wan01) - END
                  END
                  /* Verify that the FROM LOCation is not the */
                  /* CASE PICK LOCation for this product.     */
                  IF EXISTS(SELECT 1 FROM SKUxLOC (NOLOCK)
                           WHERE StorerKey = @c_CurrentStorer
                           AND   Sku = @c_CurrentSKU
                           AND   Loc = @c_FromLOC
                           AND   LocationType = 'CASE'
                           )
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Stop because LOCation Type = CASE! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU
                     END
                     --(Wan01) - START
                     GOTO FIND_NEXT_INV 
                     --BREAK -- Get out of loop, so that next cANDidate can be evaluated
                     --(Wan01) - END
                  END

                  --(Wan01) - START
                  IF @n_ReplByPiece = 1
                  BEGIN
                     IF @n_OnHandQty > @n_RemainingQty 
                     BEGIN
                        SET @n_FromQty = @n_RemainingQty 
                     END
                     ELSE
                     BEGIN
                       SET @n_FromQty = @n_OnHandQty 
                     END
                     SET @n_RemainingQty = @n_RemainingQty - @n_FromQty

                  END
                  ELSE
                  --(Wan01) - END
                  BEGIN
                     DECLARE @cLocationHandling NVARCHAR(10)
                           , @nFullCaseQty      INT 

                     SELECT @cLocationHandling = LocationHandling 
                     FROM   LOC WITH (NOLOCK) 
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
                        FROM LOTxLOCxID WITH (NOLOCK)
                        WHERE StorerKey = @c_CurrentStorer
                        AND Sku = @c_CurrentSKU
                        AND Loc = @c_FromLOC
                        AND Lot = @c_fromlot
                        AND ID  = @c_fromid

                        SELECT @n_PalletCnt = ISNULL(PACK.Pallet, 0) 
                        FROM   SKU  WITH (NOLOCK) 
                        JOIN   PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey) 
                        WHERE  SKU.StorerKey = @c_CurrentStorer
                        AND    SKU.Sku = @c_CurrentSKU
                        
                        -- If LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > Pallet Qty
                        -- Then use Pallet Qty...
                        IF @c_Overallocation = 'Y' 
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
                           SET @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullCase)

                           IF @n_OnHandQty % @n_CurrentFullCase > 0 
                           BEGIN
                              SET @n_PossibleCases = @n_PossibleCases + 1 
                           END

                           SET @nFullCaseQty = @n_PossibleCases * @n_CurrentFullCase 

                           IF @nFullCaseQty > @n_OnHandQty
                           BEGIN 
                              SET @nFullCaseQty = @n_OnHandQty 
                           END
                        END 
                     END 

                     /* How many do we take? */
                     IF @cLocationHandling = '2' -- Case Only 
                     BEGIN 
                        IF @n_RemainingQty >= @nFullCaseQty
                        BEGIN
                           SET @n_FromQty = @nFullCaseQty 
                           SET @n_RemainingQty = @n_RemainingQty - @nFullCaseQty
                        END
                        ELSE
                        BEGIN
                           -- Force to replen full case
                           IF @n_CurrentFullCase > 0 AND @n_CurrentFullCase > @nFullCaseQty 
                           BEGIN 
                              -- get full case qty 
                              SET @n_PossibleCases = FLOOR(@n_RemainingQty / @n_CurrentFullCase)
                              
                              -- trade remaining qty as 1 full case
                              IF @n_RemainingQty % @n_CurrentFullCase > 0 
                              BEGIN
                                 SET @n_PossibleCases = @n_PossibleCases + 1
                              END

                              SET @nFullCaseQty = @n_PossibleCases * @n_CurrentFullCase 

                              IF @nFullCaseQty > @n_RemainingQty 
                              BEGIN 
                                 SET @nFullCaseQty = @n_RemainingQty  
                              END
                           END 
                           ELSE 
                           BEGIN
                              SET @nFullCaseQty = @n_RemainingQty
                           END

                           SET @n_FromQty = @nFullCaseQty 
                           SET @n_RemainingQty = @n_RemainingQty - @nFullCaseQty
                        END
                     END    
                     ELSE
                     BEGIN                                          
                        IF @n_RemainingQty >= @n_FullPallet
                        BEGIN
                           SET @n_FromQty = @n_FullPallet 
                           SET @n_RemainingQty = @n_RemainingQty - @n_FullPallet
                        END
                        ELSE
                        BEGIN
                           -- Force to replen full pallet
                           SET @n_FromQty = 0
                        END
                     END 

                     IF @b_debug = 1
                     BEGIN
                        SELECT @n_CurrentSeverity '@n_CurrentSeverity', @n_FullPallet '@n_FullPallet', 
                               @nFullCaseQty '@nFullCaseQty', @n_OnHandQty '@n_OnHandQty', @n_CurrentFullCase '@n_CurrentFullCase', 
                               @n_RemainingQty '@n_RemainingQty', @cLocationHandling '@cLocationHandling'
                     END
                  END
        
                  IF @n_FromQty > 0
                  BEGIN
                     SELECT @c_Packkey = PACK.PackKey,
                            @c_UOM = PACK.PackUOM3
                     FROM   SKU  WITH (NOLOCK)
                     JOIN   PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.Packkey)
                     WHERE  SKU.StorerKey = @c_CurrentStorer
                     AND    SKU.Sku = @c_CurrentSKU

                     IF @n_continue = 1 or @n_continue = 2
                     BEGIN
                        IF NOT EXISTS(SELECT 1 FROM #REPLENISHMENT WHERE LOT =  @c_fromlot AND
                                      FromLOC = @c_FromLOC AND ID = @c_fromid)
                        BEGIN
                           INSERT #REPLENISHMENT 
                                 (
                                    StorerKey
                                 ,  SKU
                                 ,  FromLOC
                                 ,  ToLOC
                                 ,  Lot
                                 ,  Id
                                 ,  Qty
                                 ,  UOM
                                 ,  PackKey
                                 ,  Priority
                                 ,  QtyMoved
                                 ,  QtyInPickLOC
                                 )
                                    VALUES (
                                    @c_CurrentStorer
                                 ,  @c_CurrentSKU
                                 ,  @c_FromLOC
                                 ,  @c_CurrentLoc
                                 ,  @c_fromlot
                                 ,  @c_fromid
                                 ,  @n_FromQty
                                 ,  @c_UOM
                                 ,  @c_Packkey
                                 ,  @c_CurrentPriority
                                 ,  0
                                 ,  0
                                 )
                        END 
                     END
                     SET @n_numberofrecs = @n_numberofrecs + 1

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
            --(Wan01) - START
                  --IF @c_fromid = '' OR @c_fromid IS NULL OR RTRIM(@c_FromId) = ''
                  --BEGIN
                  --   -- SELECT @n_remainingqty=0
                  --   BREAK
                  --END
               --END -- SCAN LOT for ID
               --SET ROWCOUNT 0
               --FIND_NEXT_LOC: -- SOS#129030
               --FETCH NEXT FROM LOC_CUR INTO @c_FromLOC 
            --END -- SCAN LOT for LOC
            --SET ROWCOUNT 0
            --CLOSE LOC_CUR
            --DEALLOCATE LOC_CUR 

               FIND_NEXT_INV:
               FETCH NEXT FROM INV_CUR INTO @c_FromLOC
                                          , @c_fromid
                                          , @n_OnHandQty
            END -- SCAN LOT for LOC
            CLOSE INV_CUR
            DEALLOCATE INV_CUR 
            --(Wan01) - END

            FIND_NEXT_LOT:
            FETCH NEXT FROM LOT_CUR INTO @c_FromLot
         END -- LOT 
         CLOSE LOT_CUR 
         DEALLOCATE LOT_CUR 
         DROP TABLE #TMP_OVERALLOC
      --(Wan01) - START
         FIND_NEXT_SKUxLOC:
         FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                       ,  @c_CurrentSKU 
                                       ,  @c_CurrentLoc
                                       ,  @n_currentfullcase
                                       ,  @n_CurrentSeverity
                                       ,  @c_OverAllocation
                                       ,  @n_QtyExpected
      END -- -- FOR SKUxLOC
      CLOSE CUR_SKUxLOC
      DEALLOCATE CUR_SKUxLOC
      --(Wan01) - END
   END 
   --SET ROWCOUNT 0
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      /* Update the column QtyInPickLOC in the Replenishment Table */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         UPDATE #REPLENISHMENT SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked
         FROM SKUxLOC WITH (NOLOCK)
         WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey AND
         #REPLENISHMENT.SKU = SKUxLOC.SKU AND
         #REPLENISHMENT.toLOC = SKUxLOC.LOC
      END
   END
   /* Insert Into Replenishment Table Now */
   DECLARE @b_success   INT
         , @n_err       INT
         , @c_errmsg    NVARCHAR(255)

   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT R.FromLoc
         ,R.Id
         ,R.ToLoc
         ,R.Sku
         ,R.Qty
         ,R.StorerKey
         ,R.Lot
         ,R.PackKey
         ,R.Priority
         ,R.UOM
   FROM #REPLENISHMENT R

   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_FromLOC
                           , @c_FromID
                           , @c_CurrentLoc
                           , @c_CurrentSKU
                           , @n_FromQty
                           , @c_CurrentStorer
                           , @c_FromLot
                           , @c_PackKey
                           , @c_Priority
                           , @c_UOM
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXECUTE nspg_GetKey
            'REPLENISHKEY'
         ,  10
         ,  @c_ReplenishmentKey  OUTPUT
         ,   @b_success          OUTPUT 
         ,   @n_err              OUTPUT 
         ,   @c_errmsg           OUTPUT

      IF NOT @b_success = 1
      BEGIN
         BREAK
      END

      IF @b_success = 1
      BEGIN
         INSERT REPLENISHMENT 
            (
               replenishmentgroup
            ,  ReplenishmentKey
            ,  StorerKey
            ,  Sku
            ,  FromLoc
            ,  ToLoc
            ,  Lot
            ,  Id
            ,  Qty
            ,  UOM
            ,  PackKey
            ,  Confirmed
            )
               VALUES (
               'IDS'
            ,  @c_ReplenishmentKey 
            ,  @c_CurrentStorer 
            ,  @c_CurrentSKU 
            ,  @c_FromLOC 
            ,  @c_CurrentLoc 
            ,  @c_FromLot 
            ,  @c_FromId 
            ,  @n_FromQty 
            ,  @c_UOM 
            ,  @c_PackKey 
            ,  'N'
            )
         SET @n_err = @@ERROR

      END -- IF @b_success = 1

      FETCH NEXT FROM CUR1 INTO @c_FromLOC
                              , @c_FromID
                              , @c_CurrentLoc
                              , @c_CurrentSKU
                              , @n_FromQty
                              , @c_CurrentStorer
                              , @c_FromLot
                              , @c_PackKey
                              , @c_Priority
                              , @c_UOM
   END -- While
   CLOSE CUR1 
   DEALLOCATE CUR1
   -- End Insert Replenishment

   --(Wan02) - START
   QUIT_SP:
      IF @c_FuncType IN ( 'G' )                                     
      BEGIN
         RETURN
      END
   --(Wan02) - END

      IF ( @c_zone02 = 'ALL')
      BEGIN
         SELECT R.FromLoc
               ,R.Id
               ,R.ToLoc
               ,R.Sku
               ,R.Qty
               ,R.StorerKey
               ,R.Lot
               ,R.PackKey
               ,SKU.Descr
               ,R.Priority
               ,LOC.PutawayZone
               ,PACK.CaseCnt
               ,PACK.PackUOM1
               ,PACK.PackUOM3
               ,R.ReplenishmentKey
               ,LA.Lottable02
         FROM  REPLENISHMENT R WITH (NOLOCK) 
         JOIN  SKU             WITH (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
         JOIN  LOC             WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
         JOIN  PACK            WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
         JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (R.Lot = LA.Lot)   
         WHERE LOC.facility = @c_zone01
         AND  (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') 
         AND  (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')       --(Wan02)  
         AND   R.confirmed = 'N' 
         ORDER BY LOC.PutawayZone
                , R.Priority
      END
      ELSE
      BEGIN
          SELECT R.FromLoc
               ,R.Id
               ,R.ToLoc
               ,R.Sku
               ,R.Qty
               ,R.StorerKey
               ,R.Lot
               ,R.PackKey
               ,SKU.Descr
               ,R.Priority
               ,LOC.PutawayZone
               ,PACK.CaseCnt
               ,PACK.PackUOM1
               ,PACK.PackUOM3
               ,R.ReplenishmentKey
               ,LA.Lottable02
         FROM  REPLENISHMENT R WITH (NOLOCK) 
         JOIN  SKU             WITH (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
         JOIN  LOC             WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
         JOIN  PACK            WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
         JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (R.Lot = LA.Lot)  
         WHERE LOC.facility = @c_zone01
         AND  (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') 
         AND  (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')       --(Wan02)  
         AND  LOC.PutawayZone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         AND R.Confirmed = 'N'
         ORDER BY LOC.PutawayZone
               ,  R.Priority
      END
END

GO