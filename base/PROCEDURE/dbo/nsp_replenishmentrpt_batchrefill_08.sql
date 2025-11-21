SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_ReplenishmentRpt_BatchRefill_08                */
/* Creation Date:   25-Nov-2008                                         */
/* Copyright: IDS                                                       */
/* Written by:     YTwan                                                */
/*                                                                      */
/* Purpose:   SOS 122372 -                                              */
/*            Wave Replenishment Report FIFO                            */
/*                                                                      */
/* Input Parameters:  @c_zone01           NVARCHAR(10)                  */
/*                   ,@c_zone02           NVARCHAR(10)                  */
/*                   ,@c_zone03           NVARCHAR(10)                  */
/*                   ,@c_zone04           NVARCHAR(10)                  */
/*                   ,@c_zone05           NVARCHAR(10)                  */
/*                   ,@c_zone06           NVARCHAR(10)                  */
/*                   ,@c_zone07           NVARCHAR(10)                  */
/*                   ,@c_zone08           NVARCHAR(10)                  */
/*                   ,@c_zone09           NVARCHAR(10)                  */    
/*                   ,@c_zone10           NVARCHAR(10)                  */
/*                   ,@c_zone11           NVARCHAR(10)                  */
/*                   ,@c_zone12           NVARCHAR(10)                  */
/*                   ,@c_storerkey        NVARCHAR(15)                  */
/*                                                                      */
/* Output Parameters: Report                                            */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: RCM report                                                */
/*                                                                      */
/* PVCS Version: 1.4       -- Change this PVCS next version release     */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.  Purposes                                 */ 
/* 18-June-2009 Audrey   1.1   SOS#138985 - Bug fix for lottables and   */  
/*                                          rewrite the Replenishment   */         
/*                                          logic by Shong              */
/* 21-Mar-2012  KHLim01  1.2   Reduce blocking                          */
/* 05-MAR-2018  Wan01    1.3   WM - Add Functype                        */
/* 05-OCT-2018  CZTENG01 1.4   WM - Add ReplGrp                         */
/************************************************************************/

CREATE PROC  [dbo].[nsp_ReplenishmentRpt_BatchRefill_08]
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
,              @c_storerkey   NVARCHAR(15)
,              @c_ReplGrp     NVARCHAR(30) = 'ALL' --(CZTENG01)
,              @c_Functype    NCHAR(1) = ''        --(Wan01)
AS
BEGIN
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        


   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   ,               @n_starttcnt   int

   DECLARE  @b_debug int,
            @c_Packkey NVARCHAR(10),
            @c_UOM     NVARCHAR(10), 
            @n_qtytaken int,
            @n_ROWREF   INT, -- KHLim01
            @n_Rowcnt   INT, -- KHLim01
            @n_ReplenishmentKey INT  -- KHLim01
        
   SET @n_continue=1
   SET @b_debug = 0
   SELECT @n_starttcnt=@@TRANCOUNT  -- KHLim01

   IF ISNULL(LTRIM(RTRIM(@c_zone12)),'') <> ''
      SELECT @b_debug = CAST( @c_zone12 AS int)

   DECLARE @c_priority  NVARCHAR(5)
   
   --(Wan01) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
   --(Wan01) - END    
   
   IF @c_FuncType IN ( '','G' )                                      --(Wan01)
   BEGIN                                                             --(Wan01)  
      -- KHLim01 start
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      CREATE TABLE #REPLENISHMENT
      (     
            ROWREF   INT IDENTITY(1,1) NOT NULL Primary Key,
            REPLENISHMENT NVARCHAR(10) NOT NULL DEFAULT '',
            StorerKey NVARCHAR(20) NOT NULL,
            SKU      NVARCHAR(20)  NOT NULL,
            FROMLOC  NVARCHAR(10)  NOT NULL,
            ToLOC    NVARCHAR(10)  NOT NULL,
            LOT      NVARCHAR(10)  NOT NULL,
            ID       NVARCHAR(18)  NOT NULL,
            QTY      INT          NOT NULL,
            QtyMoved INT          NOT NULL,
            QtyInPickLOC INT      NOT NULL,
            Priority  NVARCHAR(5),
            UOM       NVARCHAR(10) NOT NULL,
            PACKKEY   NVARCHAR(10) NOT NULL 
            )
         
      CREATE TABLE #TempSKUxLOC
      (
            ROWREF   INT IDENTITY(1,1) NOT NULL Primary Key,
            ReplenishmentPriority NVARCHAR(5) NOT NULL, 
            ReplenishmentSeverity INT  NOT NULL,
            StorerKey             NVARCHAR(15) NOT NULL,
            SKU                   NVARCHAR(20) NOT NULL,
            LOC                   NVARCHAR(10),
            ReplenishmentCasecnt  INT NOT NULL
      )
      -- KHLim01 end

   --   SELECT StorerKey, 
   --          SKU, 
   --          LOC as FromLOC, 
   --          LOC as ToLOC, 
   --          Lot, 
   --          Id, 
   --          Qty, 
   --          Qty as QtyMoved, 
   --          Qty as QtyInPickLOC,
   --          @c_priority as Priority, 
   --          Lot as UOM, 
   --          Lot PackKey
   --   INTO #REPLENISHMENT
   --   FROM LOTxLOCxID WITH (NOLOCK)
   --   WHERE 1 = 2
   
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         DECLARE @c_CurrentSKU       NVARCHAR(20), 
                 @c_CurrentStorer    NVARCHAR(15),
                 @c_CurrentLOC       NVARCHAR(10), 
                 @c_CurrentPriority  NVARCHAR(5),
                 @n_CurrentFullCase  int, 
                 @n_CurrentSeverity  int,
                 @c_FromLOC          NVARCHAR(10), 
                 @c_fromlot          NVARCHAR(10),
                 @c_fromid           NVARCHAR(18),
                 @n_FromQty          int,   
                 @n_remainingqty     int, 
                 @n_PossibleCases    int,
                 @n_remainingcases   int, 
                 @n_OnHandQty        int, 
                 @n_fromcases        int,
                 @c_ReplenishmentKey NVARCHAR(10), 
                 @n_numberofrecs     int, 
                 @n_limitrecs        int,
                 @c_OverallocatedLot         NVARCHAR(10),      -- SOS138985
                 @b_DoneCheckOverAllocatedLots int,
                 @n_SKULocAvailableQty         int

         SET @c_CurrentSKU = '' 
         SET @c_CurrentStorer = ''
         SET @c_CurrentLOC = ''
         SET @c_CurrentPriority = ''
         SET @n_CurrentFullCase = 0   
         SET @n_CurrentSeverity = 9999999 
         SET @n_FromQty = 0
         SET @n_remainingqty = 0
         SET @n_PossibleCases = 0
         SET @n_remainingcases =0
         SET @n_fromcases = 0
         SET @n_numberofrecs = 0
         SET @n_limitrecs = 5
      
         /* Make a temp version of SKUxLOC */
   --      SELECT ReplenishmentPriority,     -- KHLim01
   --             ReplenishmentSeverity,
   --             StorerKey,
   --             SKU, 
   --             LOC, 
   --             ReplenishmentCasecnt
   --      INTO #TempSKUxLOC
   --      FROM SKUxLOC WITH (NOLOCK)
   --      WHERE 1=2
      
         IF (@c_zone02 = 'ALL')
         BEGIN
            INSERT #TempSKUxLOC
            SELECT DISTINCT 
                   SKUxLOC.ReplenishmentPriority,
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
              JOIN LOC     WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
              JOIN SKU     WITH (NOLOCK) ON (SKUxLOC.StorerKey = SKU.StorerKey AND  SKUxLOC.SKU = SKU.SKU)
              JOIN PACK    WITH (NOLOCK) ON (SKU.PackKey = PACK.PACKKey) 
              JOIN (SELECT SKUxLOC.STORERKEY, 
                           SKUxLOC.SKU, 
                           SKUxLOC.LOC 
                     FROM  SKUxLOC WITH (NOLOCK) 
                     JOIN  LOC     WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                     WHERE SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0 
                     AND   SKUxLOC.LocationType NOT IN ('PICK','CASE') 
                     AND   LOC.FACILITY = @c_Zone01 
                     AND   LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') ) AS SL 
                                         ON (SL.STORERKEY = SKUxLOC.StorerKey AND SL.SKU = SKUxLOC.SKU) 
            WHERE LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
              AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')
              AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
              AND  LOC.FACILITY = @c_Zone01
              AND (SKUXLOC.Storerkey = @c_storerkey OR @c_storerkey = 'ALL') 
                  -- AND  SKUxLOC.SKu = '076647060230'

         END
         ELSE
         BEGIN
            INSERT #TempSKUxLOC
            SELECT DISTINCT 
                   SKUxLOC.ReplenishmentPriority,
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
             JOIN LOC     WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
             JOIN SKU     WITH (NOLOCK) ON (SKUxLOC.StorerKey = SKU.StorerKey AND  SKUxLOC.SKU = SKU.SKU)
             JOIN PACK    WITH (NOLOCK) ON (SKU.PackKey = PACK.PACKKey) 
             JOIN (SELECT SKUxLOC.STORERKEY, 
                          SKUxLOC.SKU, 
                          SKUxLOC.LOC 
                     FROM SKUxLOC WITH (NOLOCK) 
                     JOIN LOC     WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                    WHERE SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0
                      AND SKUxLOC.LocationType NOT IN ('PICK','CASE')
                      AND LOC.FACILITY = @c_Zone01 
                      AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') ) AS SL 
                                        ON (SL.STORERKEY = SKUxLOC.StorerKey AND SL.SKU = SKUxLOC.SKU) 
           WHERE LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND  (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')
            AND  (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
            AND  LOC.FACILITY = @c_Zone01
            AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
            AND (SKUXLOC.Storerkey = @c_storerkey OR @c_storerkey = 'ALL') 
         END
         IF @b_debug = 1
         BEGIN
            SELECT 'TEMPSKUxLOC table'
            SELECT * FROM #TEMPSKUxLOC (NOLOCK)
            ORDER BY ReplenishmentPriority, ReplenishmentSeverity desc, Storerkey, Sku, LOc
         END

         -- SELECT @n_starttcnt=@@TRANCOUNT  -- KHLim01

         BEGIN TRANSACTION

         WHILE (1=1) -- while 1
         BEGIN
            SET ROWCOUNT 1

            SELECT @c_CurrentPriority = ReplenishmentPriority
              FROM #TempSKUxLOC
             WHERE ReplenishmentPriority > @c_CurrentPriority
               AND ReplenishmentCasecnt > 0
          ORDER BY ReplenishmentPriority

            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            IF @b_debug = 1
            BEGIN
               Print 'Working on @c_CurrentPriority:' + RTRIM(@c_CurrentPriority)
            END 

            SET ROWCOUNT 0
            /* Loop through SKUxLOC for the currentSKU, current storer */
            /* to pickup the next severity */

            SET @n_CurrentSeverity = 999999999
            WHILE (1=1) -- while 2
            BEGIN
               SET ROWCOUNT 1
               SELECT @n_CurrentSeverity = ReplenishmentSeverity
                 FROM #TempSKUxLOC
                WHERE ReplenishmentSeverity < @n_CurrentSeverity
                  AND ReplenishmentPriority = @c_CurrentPriority
                  AND ReplenishmentCasecnt > 0
             ORDER BY ReplenishmentSeverity DESC

               IF @@ROWCOUNT = 0
               BEGIN
                  SET ROWCOUNT 0
                  BREAK
               END

               SET ROWCOUNT 0

               IF @b_debug = 1
               BEGIN
                  Print 'Working on @n_CurrentSeverity:' + RTRIM(@n_CurrentSeverity)
               END 

               /* Now - for this priority, this severity - find the next storer row */
               /* that matches */
               SET @c_CurrentSKU = '' 
               SET @c_CurrentStorer = ''

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
                     Print 'Working on @c_CurrentStorer:' + RTRIM(@c_CurrentStorer)
                  END 
                  /* Now - for this priority, this severity - find the next SKU row */
                  /* that matches */

                  -- 3-Sept-2004 YTWAN  NIKE BSWH Replenishment  - START
                  SET @c_CurrentSKU = ''

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
                        Print 'Working on @c_CurrentSKU:' + RTRIM(@c_CurrentSKU) 
                     END 
                 
                     SET @c_CurrentLOC = ''

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
                           Print 'Working on @c_CurrentLOC:' + RTRIM(@c_CurrentLOC) 
                        END 
      
                        /* We now have a pickLocation that needs to be replenished! */
                        /* Figure out which Locations in the warehouse to pull this product from */
                        /* End figure out which Locations in the warehouse to pull this product from */
                        SET @c_FromLOC = ''  
                        SET @c_fromlot = '' 
                        SET @c_fromid = ''
                        SET @n_FromQty = 0 
                        SET @n_PossibleCases = 0
                        SET @n_remainingqty = @n_CurrentSeverity * @n_CurrentFullCase -- by jeff, used to calculate qty required per LOT, 
                                                                                      -- rather than from SKUxLOC
                        SET @n_remainingcases = @n_CurrentSeverity
                        SET @c_OverallocatedLot = ''      -- SOS138985
                        SET @b_DoneCheckOverAllocatedLots = 0
                            
                        DECLARE     @c_uniquekey  NVARCHAR(40), 
                                    @c_uniquekey2 NVARCHAR(40)
                     
                        DECLARE @t_OverAllocatedLot Table (LOT NVARCHAR(10))       -- SOS138985

                        SET @c_uniquekey = ''
                        SET @c_uniquekey2 = ''

      -- sos138985 start
                        -- Get All the LOT# that already overallocated      
                        -- Take this LOT# as 1st Priority      
                        INSERT INTO @t_OverAllocatedLot       
                        SELECT DISTINCT LOTxLOCxID.LOT       
                        FROM LOTxLOCxID   WITH (NOLOCK)      
                        JOIN LOC          WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC      
                        JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTxLOCxID.LOT = LOTATTRIBUTE.LOT      
                        JOIN LOT          WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT       
                        WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer      
                        AND LOTxLOCxID.SKU = @c_CurrentSKU      
                        AND LOC.LocationFlag <> 'DAMAGE'      
                        AND LOC.LocationFlag <> 'HOLD'                         
                        AND LOC.Status <> 'HOLD'      
                        AND LOT.Status <> 'HOLD'      
                        AND ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) - LOTxLOCxID.qty) > 0 -- SOS 6217      
                        AND LOTxLOCxID.LOC = @c_CurrentLOC      
                        AND LOC.Facility = @c_zone01       
                        AND LOTATTRIBUTE.Lottable02 NOT IN (SELECT CODELKUP.Code FROM CODELKUP WITH (NOLOCK)       
                        WHERE Listname = 'GRADE_B')       
      
                        IF @b_debug = 1      
                        BEGIN      
                           SELECT CASE WHEN OA.LOT IS NOT NULL THEN 1 ELSE 9 END AS Piority,       
                                  LOTxLOCxID.LOT,      
                                  LOTxLOCxID.LOC,      
                                  LOTxLOCxID.ID,      
                                  LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked)       
                             FROM LOTxLOCxID WITH (NOLOCK)       
                             JOIN LOC        WITH (NOLOCK)   ON (LOTxLOCxID.LOC = LOC.LOC)      
                             JOIN SKUXLOC    WITH (NOLOCK)   ON (LOTxLOCxID.StorerKey = SKUXLOC.Storerkey)      
                                                            AND (LOTxLOCxID.SKU = SKUXLOC.SKU)      
                                                   AND (LOTxLOCxID.LOC = SKUXLOC.LOC)      
                             JOIN ID         WITH (NOLOCK)   ON (LOTxLOCxID.ID = ID.ID)      
                             JOIN LOT        WITH (NOLOCK)   ON (LOTxLOCxID.LOT = LOT.LOT)      
                             JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTATTRIBUTE.LOT = LOT.LOT)       
                             LEFT OUTER JOIN @t_OverAllocatedLot OA ON OA.LOT = LOTxLOCxID.LOT      
                           WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer      
                              AND LOTxLOCxID.SKU = @c_CurrentSKU      
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC      
                              AND (SKUXLOC.LOCATIONTYPE <> 'CASE')      
                              AND (SKUXLOC.LOCATIONTYPE <> 'PICK')      
                              AND LOC.Facility   = @c_zone01      
                              AND (LOT.Status <> 'HOLD')       
                              AND (LOC.Status <> 'HOLD')      
                              AND (LOC.LocationFlag <> 'DAMAGE')      
                              AND (LOC.LocationFlag <> 'HOLD')      
                              AND (ID.Status <> 'HOLD')      
                              AND (LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0       
                              AND NOT EXISTS ( SELECT 1      
                                               FROM CODELKUP WITH (NOLOCK)       
                                              WHERE CODELKUP.Code = LOTATTRIBUTE.Lottable02      
                                                AND CODELKUP.Listname = 'GRADE_B') -- SOS#107158      
                         ORDER BY       
        CASE WHEN OA.LOT IS NOT NULL THEN 1 ELSE 9 END,       
                              LOTATTRIBUTE.Lottable05,      
                              LOTxLOCxID.Qty,      
                              LOTxLOCxID.Loc,      
                              LOTxLOCxID.Lot,      
                              LOTxLOCxID.ID DESC      
                              END       
      
                        DECLARE CUR_Replenishment CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
                           SELECT LOTxLOCxID.LOT,      
                                  LOTxLOCxID.LOC,      
                                  LOTxLOCxID.ID,      
                                  LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked)       
                             FROM LOTxLOCxID WITH (NOLOCK)       
                             JOIN LOC        WITH (NOLOCK)   ON (LOTxLOCxID.LOC = LOC.LOC)      
                             JOIN SKUXLOC    WITH (NOLOCK)   ON (LOTxLOCxID.StorerKey = SKUXLOC.Storerkey)      
                                                            AND (LOTxLOCxID.SKU = SKUXLOC.SKU)      
                                        AND (LOTxLOCxID.LOC = SKUXLOC.LOC)      
                             JOIN ID         WITH (NOLOCK)   ON (LOTxLOCxID.ID = ID.ID)      
                             JOIN LOT        WITH (NOLOCK)   ON (LOTxLOCxID.LOT = LOT.LOT)      
                             JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTATTRIBUTE.LOT = LOT.LOT)       
                             LEFT OUTER JOIN @t_OverAllocatedLot OA ON OA.LOT = LOTxLOCxID.LOT      
                             WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer      
                              AND LOTxLOCxID.SKU = @c_CurrentSKU      
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC      
                              AND (SKUXLOC.LOCATIONTYPE <> 'CASE')      
                              AND (SKUXLOC.LOCATIONTYPE <> 'PICK')      
                              AND LOC.Facility   = @c_zone01      
                              AND (LOT.Status <> 'HOLD')       
                              AND (LOC.Status <> 'HOLD')      
                              AND (LOC.LocationFlag <> 'DAMAGE')      
                              AND (LOC.LocationFlag <> 'HOLD')      
                              AND (ID.Status <> 'HOLD')      
                              AND (LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0       
                              AND NOT EXISTS ( SELECT 1      
                                               FROM CODELKUP WITH (NOLOCK)       
                                               WHERE CODELKUP.Code = LOTATTRIBUTE.Lottable02      
                                               AND CODELKUP.Listname = 'GRADE_B') -- SOS#107158      
                            ORDER BY       
                            CASE WHEN OA.LOT IS NOT NULL THEN 1 ELSE 9 END,       
                            LOTATTRIBUTE.Lottable05,      
                            LOTxLOCxID.Qty,      
                            LOTxLOCxID.Loc,      
                            LOTxLOCxID.Lot,      
                            LOTxLOCxID.ID DESC      
      
                        OPEN CUR_Replenishment      
         
                        FETCH NEXT FROM CUR_Replenishment INTO @c_fromlot, @c_fromloc, @c_fromid, @n_OnHandQty      
                        WHILE (@@FETCH_STATUS <> -1 AND @n_remainingqty > 0)  -- while 5      
                        BEGIN      
      -- sos138985 end
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Selected Lot' , @c_fromlot
                              END
                    
                              GET_REPLENISH_RECORD:

                              SELECT @n_OnHandQty = @n_OnHandQty - SUM(#REPLENISHMENT.Qty)
                                FROM #REPLENISHMENT
                               WHERE #REPLENISHMENT.Lot     = @c_fromlot
                                 AND #REPLENISHMENT.FromLoc = @c_fromloc
                                 AND #REPLENISHMENT.ID      = @c_fromid
                            GROUP BY #REPLENISHMENT.Lot, 
                                     #REPLENISHMENT.FromLoc, 
                                     #REPLENISHMENT.ID 

                              /* How many cases can I get from this record? */
                              SET @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullCase)
                           
                              IF @b_debug = 1
                              BEGIN
                                 SELECT '@n_OnHandQty' = @n_OnHandQty , '@n_RemainingQty' = @n_RemainingQty
                                 SELECT '@n_possiblecases' = @n_possiblecases , '@n_currentFullCase' = @n_currentFullCase
                              END
                              /* How many do we take? */
                              IF @n_OnHandQty > @n_RemainingQty
                              BEGIN
                                 -- Modify by SHONG for full carton only
                                 -- Take Full Case if the qty need to replenish < carton
                                 IF @n_OnHandQty >= @n_CurrentFullCase AND @n_RemainingQty <= @n_CurrentFullCase
                                 BEGIN 
                                    SET @n_FromQty = @n_CurrentFullCase
                                    SET @n_RemainingQty = 0
                                 END            
                                 ELSE IF @n_OnHandQty >= @n_CurrentFullCase AND @n_RemainingQty > @n_CurrentFullCase
                                 BEGIN 
                                    SET @n_PossibleCases = floor(@n_RemainingQty / @n_CurrentFullCase)
                                    IF (@n_RemainingQty / @n_CurrentFullCase) > @n_PossibleCases AND
                                       (@n_PossibleCases * @n_CurrentFullCase) < @n_RemainingQty
                                    BEGIN
                                       -- take one more case
                                       SET @n_PossibleCases = @n_PossibleCases + 1
                                    END

                                    SET @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase)

                                    SET @n_RemainingQty = 0
                                 END            
                                 ELSE 
                                 BEGIN 
                                    -- By SHONG SOS#110598
                                    -- User want to take all the remaining Qty in the Bulk
                                    -- Location if it less then 1 Carton 
                                    -- SELECT @n_FromQty = @n_RemainingQty
                                    IF @n_OnHandQty <= @n_CurrentFullCase
                                    BEGIN
                                       SET @n_FromQty = @n_OnHandQty  
                                    END
                                    ELSE
                                    BEGIN 
                                       SET @n_FromQty = @n_RemainingQty 
                                    END
                                    SET @n_RemainingQty = 0
                                 END 
                             END
                             ELSE
                             BEGIN
                                 -- Modify by shong for full carton only
   
                                 IF @n_OnHandQty > @n_CurrentFullCase
                                 BEGIN 
                                    /* Total Carton On Hand > Total Carton to take and With Loose Qty > 0 ? */
                                    IF (@n_OnHandQty / @n_CurrentFullCase) > @n_PossibleCases AND
                                       (@n_PossibleCases * @n_CurrentFullCase) < @n_FromQty
                                    BEGIN
                                       -- take one more case
                                       SET @n_PossibleCases = @n_PossibleCases + 1
                                    END

                                    SET @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase)
                                 END
                                 ELSE
                                 BEGIN
                                    -- Added By SHONG on 13th May 2008
                                    IF @n_OnHandQty = (SELECT SUM(Qty - QtyAllocated - QtyPicked) 
                                                         FROM LOTxLOCxID WITH (NOLOCK) 
                                                        WHERE LOT = @c_fromlot
                                                          AND Loc = @c_fromloc
                                                          AND ID  = @c_fromid ) 
                                    BEGIN
                                       SET @n_FromQty = @n_OnHandQty
                                    END
                                    ELSE
                                    BEGIN
                                       SET @n_FromQty = 0 
                                    END 
                                 END
                               
                                 SET @n_remainingqty = @n_remainingqty - @n_FromQty
                             
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
                                   FROM SKU  WITH (NOLOCK),
                                        PACK WITH (NOLOCK)
                                  WHERE SKU.PackKey = PACK.Packkey
                                    AND SKU.StorerKey = @c_CurrentStorer
                                    AND SKU.SKU = @c_CurrentSKU
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
                                 SET @n_numberofrecs = @n_numberofrecs + 1
                              END -- if from qty > 0

                              IF @b_debug = 1
                              BEGIN
                                 SELECT @c_CurrentSKU ' SKU', @c_CurrentLOC 'LOC', @c_CurrentPriority 'priority', 
                                        @n_CurrentFullCase 'full case', @n_CurrentSeverity 'severity'
                                 -- SELECT @n_FromQty 'qty', @c_FromLOC 'fromLOC', @c_fromlot 'from lot', @n_PossibleCases 'possible cases'
                                 SELECT @n_remainingqty '@n_remainingqty', @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU, 
                                        @c_fromlot 'from lot', @c_fromid
                              END
                     
                           FETCH NEXT FROM CUR_Replenishment INTO @c_fromlot, @c_fromloc, @c_fromid, @n_OnHandQty      
                        END -- While Cursor loop (CUR_Replenishment)      
                        CLOSE CUR_Replenishment      
                        DEALLOCATE CUR_Replenishment      
   --                        END -- SCAN LOT FOR LOT        
   --                        SET ROWCOUNT 0
                        END  -- FOR LOC
                        SET ROWCOUNT 0
                     END -- FOR SKU
                     -- 3-Sept-2004 YTWAN  NIKE BSWH Replenishment  - END
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
            UPDATE #REPLENISHMENT 
               SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked
              FROM SKUxLOC WITH (NOLOCK)
             WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey 
               AND #REPLENISHMENT.SKU = SKUxLOC.SKU 
               AND #REPLENISHMENT.toLOC = SKUxLOC.LOC
         END
      END

     -- KHLim01 start
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END

      IF @n_continue=1 OR @n_continue=2
      BEGIN 
         SET @n_Rowcnt = 0
         SELECT    @n_Rowcnt = Count(1)
         FROM   #REPLENISHMENT R
      
         IF ISNULL(@n_Rowcnt, 0) > 0
         BEGIN
               -- Get Key by BATCH
            DECLARE @b_success int,
            @n_err     int,
            @c_errmsg  NVARCHAR(255)   
         
            BEGIN TRAN
                  
            EXECUTE nspg_GetKey
            'REPLENISHKEY',
            10,
            @c_ReplenishmentKey OUTPUT,
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT,
            0,
            @n_Rowcnt
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63529   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to get REPLENISHKEY. (nsp_ReplenishmentRpt_BatchRefill_08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END    
            ELSE
            BEGIN 
               COMMIT TRAN
            END     
         END
      END   

      IF @n_continue=1 OR @n_continue=2
      BEGIN   
         /* Insert Into Replenishment Table Now */

         SET @n_ReplenishmentKey = CAST(@c_ReplenishmentKey as INT)
      
         BEGIN TRAN
         DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT R.ROWREF
         FROM   #REPLENISHMENT R
         OPEN CUR1

         FETCH NEXT FROM CUR1 INTO @n_ROWREF
         WHILE @@FETCH_STATUS <> -1
         BEGIN
        
           SET @c_ReplenishmentKey = dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(CHAR(10),@n_ReplenishmentKey))) 
           SET @c_ReplenishmentKey = RIGHT(dbo.fnc_RTrim(Replicate('0',10) + @c_ReplenishmentKey),10)
         
           INSERT REPLENISHMENT (
               replenishmentgroup,
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
           SELECT
               'IDS',
               @c_ReplenishmentKey,
               R.StorerKey, 
               R.Sku,
               R.FromLoc,
               R.ToLoc,
               R.Lot,
               R.Id,
               R.Qty, 
               R.UOM,
               R.PackKey,
               'N'
            FROM #REPLENISHMENT R (NOLOCK)
            WHERE R.ROWREF = @n_ROWREF
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63524   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into Replenishment table failed. (nsp_ReplenishmentRpt_BatchRefill_08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END

            Set @n_ReplenishmentKey = @n_ReplenishmentKey + 1

            FETCH NEXT FROM CUR1 INTO @n_ROWREF
         END -- While
         CLOSE CUR1 
         DEALLOCATE CUR1
           
         COMMIT TRAN
      END   


      IF @n_continue=1 OR @n_continue=2
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
      -- KHLim01 end

      -- End Insert Replenishment
      IF @n_continue=3  -- Error Occured - Process AND Return
      BEGIN
         SET @b_success = 0
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishmentRpt_BatchRefill_08'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
      ELSE
      BEGIN
         SET @b_success = 1
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
           COMMIT TRAN
         END
         -- RETURN
      END
   END                                                               --(Wan01)
   --(Wan01) - START
   IF @c_FuncType = 'G'                                              
   BEGIN                                                             
      GOTO QUIT_SP
   END                                                              
   --(Wan01) - END
   IF ( @c_zone02 = 'ALL')
   BEGIN
      SELECT R.FromLoc, 
             R.Id, 
             R.ToLoc, 
             R.Sku, 
             R.Qty, 
             R.StorerKey, 
             R.Lot, 
             R.PackKey,
             SKU.Descr, 
             R.Priority, 
             L1.PutawayZone, 
             PACK.CASECNT, 
             PACK.PACKUOM1, 
             PACK.PACKUOM3, 
             R.ReplenishmentKey, 
             (LT.Qty - LT.QtyAllocated - LT.QtyPicked), 
             LA.Lottable02, 
             /*LA.Lottable04    SOS138985*/       
             LA.Lottable03    /*SOS138985*/  
      FROM  REPLENISHMENT R WITH (NOLOCK),
            SKU             WITH (NOLOCK), 
            LOC L1          WITH (NOLOCK), 
            PACK            WITH (NOLOCK),  
            LOC L2          WITH (nolock), 
            LOTxLOCxID LT   WITH (nolock), 
            LOTATTRIBUTE LA WITH (NOLOCK)-- Pack table added by Jacob Date Jan 03, 2001
      WHERE SKU.Sku = R.Sku
        AND SKU.StorerKey = R.StorerKey
        AND L1.Loc = R.ToLoc
        AND L2.Loc = R.FromLoc
        AND LT.Lot = R.Lot
        AND LT.Loc = R.FromLoc
        AND LT.ID = R.ID
        AND LT.LOT = LA.LOT
        AND LT.SKU = LA.SKU
        AND LT.STORERKEY = LA.STORERKEY
        AND SKU.PackKey = PACK.PackKey
        AND R.confirmed = 'N'
        AND L1.Facility = @c_zone01
        AND (R.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')
        AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')   --(Wan01)
   ORDER BY L1.PutawayZone, R.Priority
   END
   ELSE
   BEGIN
      SELECT R.FromLoc, 
             R.Id, 
             R.ToLoc, 
             R.Sku, 
             R.Qty, 
             R.StorerKey, 
             R.Lot, 
             R.PackKey,
             SKU.Descr, 
             R.Priority, 
             L1.PutawayZone, 
             PACK.CASECNT, 
             PACK.PACKUOM1, 
             PACK.PACKUOM3, 
             R.ReplenishmentKey, 
             (LT.Qty - LT.QtyAllocated - LT.QtyPicked), 
             LA.Lottable02,  
             /*LA.Lottable04    SOS138985*/       
             LA.Lottable03    /*SOS138985*/  
        FROM REPLENISHMENT R WITH (NOLOCK), 
             SKU             WITH (NOLOCK), 
             LOC L1          WITH (NOLOCK), 
             LOC L2          WITH (NOLOCK), 
             PACK            WITH (NOLOCK), 
             LOTxLOCxID LT   WITH (NOLOCK), 
             LOTATTRIBUTE LA WITH (NOLOCK) -- Pack table added by Jacob Date Jan 03, 2001
       WHERE SKU.Sku = R.Sku
         AND SKU.StorerKey = R.StorerKey
         AND L1.Loc = R.ToLoc
         AND L2.Loc = R.FromLoc
         AND LT.Lot = R.Lot
         AND LT.Loc = R.FromLoc
         AND LT.ID = R.ID
         AND LT.LOT = LA.LOT
         AND LT.SKU = LA.SKU
         AND LT.STORERKEY = LA.STORERKEY
         AND SKU.PackKey = PACK.PackKey
         AND R.confirmed = 'N'
         AND L1.Facility = @c_zone01
         AND L1.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, 
                                @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
         AND (R.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')
         AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)
      ORDER BY L1.PutawayZone, R.Priority
   END
   QUIT_SP:                                                          --(Wan01)
END

GO