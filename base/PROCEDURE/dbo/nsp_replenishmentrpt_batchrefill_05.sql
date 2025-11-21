SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: nsp_ReplenishmentRpt_BatchRefill_05                              */
/* Creation Date: 29th Nov 2005                                         */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: - Replensihment Report for IDSHK WTC principle due to diff  */
/*            LOT Allocation Sorting                                    */
/*          - Make use of SKU.PickCode for replenishment lot sorting    */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: DTS Interface                                             */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 21-Mar-2012  KHLim01  1.1  Reduce blocking                           */
/* 06-Apr-2012  NJOW01   1.2  240644 - Add storerkey param and exclude  */
/*                            hold lot                                  */
/* 05-MAR-2018  Wan01    1.4  WM - Add Functype                         */
/* 05-OCT-2018  CZTENG01 1.4  WM - Add ReplGrp                          */
/* 26-Oct-2018  TLTING01 1.3  missing nolock  , remove set rowcount     */
/************************************************************************/

CREATE PROC  [dbo].[nsp_ReplenishmentRpt_BatchRefill_05]
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
,              @c_storerkey   NVARCHAR(15) = ''  --NJOW01
,              @c_ReplGrp     NVARCHAR(30) = 'ALL' --(CZTENG01)
,              @c_Functype    NCHAR(1) = ''        --(Wan01)  


AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_DEFAULTS OFF

   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   ,               @n_starttcnt   int

   DECLARE @b_debug int,
   @c_Packkey NVARCHAR(10),
   @c_UOM     NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
   @n_qtytaken int,
   @n_SerialNo int,
   @n_ROWREF   INT, -- KHLim01
   @n_Rowcnt   INT, -- KHLim01
   @n_ReplenishmentKey INT  -- KHLim01

   SELECT @n_continue=1, @b_debug = 0
   SELECT @n_starttcnt=@@TRANCOUNT  -- KHLim01

   IF @c_zone12 <> '' AND ISNUMERIC(@c_zone12) = 1
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

      IF ISNULL(@c_Storerkey,'') = '' OR ISNULL(@c_zone11,'') <> ''  --NJOW01
         SET @c_Storerkey = 'ALL'      

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
   --   FROM LOTxLOCxID (NOLOCK)
   --   WHERE 1 = 2
   
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
         @n_SKULocAvailableQty int,
         @d_lottable05 datetime,
         @c_CtnUOM NVARCHAR(10),
         @c_InnerUOM NVARCHAR(10)

         DECLARE @c_PickCode NVARCHAR(10)

         SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
         @c_CurrentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),
         @n_CurrentFullCase = 0   , @n_CurrentSeverity = 9999999 ,
         @n_FromQty = 0, @n_remainingqty = 0, @n_PossibleCases = 0,
         @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,
         @n_limitrecs = 5
      
         /* Make a temp version of SKUxLOC */
   --      SELECT ReplenishmentPriority,           -- KHLim01
   --             ReplenishmentSeverity,StorerKey,
   --             SKU, LOC, ReplenishmentCasecnt
   --      INTO #TempSKUxLOC
   --      FROM SKUxLOC (NOLOCK)
   --      WHERE 1=2
      
         IF (@c_zone02 = 'ALL')
         BEGIN
            INSERT #TempSKUxLOC
            SELECT SKUxLOC.ReplenishmentPriority,
            ReplenishmentSeverity =
                  CASE WHEN PACK.CaseCnt > 0 
                     THEN FLOOR( ( CONVERT(real,QtyLocationLimit) - 
                                      ( CONVERT(real,SKUxLOC.Qty) - 
                                        CONVERT(real,SKUxLOC.QtyPicked) - 
                                        CONVERT(real,SKUxLOC.QtyAllocated) ) 
                                   ) / CONVERT(real,PACK.CaseCnt) )
                     WHEN PACK.InnerPack > 0 
                     THEN FLOOR( ( CONVERT(real,QtyLocationLimit) - 
                                      ( CONVERT(real,SKUxLOC.Qty) - 
                                        CONVERT(real,SKUxLOC.QtyPicked) - 
                                        CONVERT(real,SKUxLOC.QtyAllocated) ) 
                                   ) / CONVERT(real,PACK.InnerPack) )
                     ELSE QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))
                  END,
            SKUxLOC.StorerKey,
            SKUxLOC.SKU,
            SKUxLOC.LOC,
            ReplenishmentCasecnt = 
               CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt
                    WHEN PACK.InnerPack > 0 THEN PACK.InnerPack
                  ELSE 1
               END
            FROM SKUxLOC (NOLOCK), LOC (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
            WHERE SKUxLOC.LOC = LOC.LOC
            AND LOC.LocationFlag NOT IN ("DAMAGE", "HOLD")
            AND (SKUxLOC.LocationType = "PICK" or SKUxLOC.LocationType = "CASE")
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
            AND  LOC.FACILITY = @c_Zone01
            AND  SKUxLOC.StorerKey = SKU.StorerKey
            AND  SKUxLOC.SKU = SKU.SKU
            AND  SKU.PackKey = PACK.PACKKey
            AND  EXISTS( SELECT 1 FROM SKUxLOC SL (NOLOCK) WHERE SL.StorerKey = SKUxLOC.StorerKey 
                          AND SL.SKU = SKUxLOC.SKU AND SL.Qty - SL.QtyPicked - SL.QtyAllocated > 0 
                          AND SL.LOC <> SKUxLOC.LOC )
            AND (SKUXLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  --NJOW01
         END
         ELSE
         BEGIN
            INSERT #TempSKUxLOC
            SELECT SKUxLOC.ReplenishmentPriority,
            ReplenishmentSeverity =
                  CASE WHEN PACK.CaseCnt > 0 
                     THEN FLOOR( ( CONVERT(real,QtyLocationLimit) - 
                                      ( CONVERT(real,SKUxLOC.Qty) - 
                                        CONVERT(real,SKUxLOC.QtyPicked) - 
                                        CONVERT(real,SKUxLOC.QtyAllocated) ) 
                                   ) / CONVERT(real,PACK.CaseCnt) )
                     WHEN PACK.InnerPack > 0 
                      THEN FLOOR( ( CONVERT(real,QtyLocationLimit) - 
                                      ( CONVERT(real,SKUxLOC.Qty) - 
                                        CONVERT(real,SKUxLOC.QtyPicked) - 
                                        CONVERT(real,SKUxLOC.QtyAllocated) ) 
                                   ) / CONVERT(real,PACK.InnerPack) )
                     ELSE QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))
                  END,
            SKUxLOC.StorerKey,
            SKUxLOC.SKU,
            SKUxLOC.LOC,
            ReplenishmentCasecnt = 
               CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt
                    WHEN PACK.InnerPack > 0 THEN PACK.InnerPack
                  ELSE 1
               END
            FROM SKUxLOC (NOLOCK), LOC (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
            WHERE SKUxLOC.LOC = LOC.LOC
            AND LOC.LocationFlag NOT IN ("DAMAGE", "HOLD")
            AND (SKUxLOC.LocationType = "PICK" or SKUxLOC.LocationType = "CASE")
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
            AND  LOC.FACILITY = @c_Zone01
            AND  SKUxLOC.StorerKey = SKU.StorerKey
            AND  SKUxLOC.SKU = SKU.SKU
            AND  SKU.PackKey = PACK.PACKKey
            AND  EXISTS( SELECT 1 FROM SKUxLOC SL (NOLOCK) WHERE SL.StorerKey = SKUxLOC.StorerKey 
                          AND SL.SKU = SKUxLOC.SKU AND SL.Qty - SL.QtyPicked - SL.QtyAllocated > 0 
                          AND SL.LOC <> SKUxLOC.LOC )
            AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
            AND (SKUXLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  --NJOW01
         END
         IF @b_debug = 1
         BEGIN
            SELECT 'TEMPSKUxLOC table'
            SELECT * FROM #TEMPSKUxLOC (NOLOCK)
         END

         -- SELECT @n_starttcnt=@@TRANCOUNT  -- KHLim01
         BEGIN TRANSACTION
         WHILE (1=1) -- while 1
         BEGIN
            SELECT TOP 1 @c_CurrentPriority = ReplenishmentPriority
            FROM #TempSKUxLOC
            WHERE ReplenishmentPriority > @c_CurrentPriority
            AND  ReplenishmentCasecnt > 0
            ORDER BY ReplenishmentPriority
            
            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END
            
            IF @b_debug = 1
            BEGIN
               Print 'Working on @c_CurrentPriority:' + dbo.fnc_RTrim(@c_CurrentPriority)
            END 
            /* Loop through SKUxLOC for the currentSKU, current storer */
            /* to pickup the next severity */
            SELECT @n_CurrentSeverity = 999999999
            WHILE (1=1) -- while 2
            BEGIN

               SELECT TOP 1 @n_CurrentSeverity = ReplenishmentSeverity
               FROM #TempSKUxLOC
               WHERE ReplenishmentSeverity < @n_CurrentSeverity
               AND ReplenishmentPriority = @c_CurrentPriority
               AND  ReplenishmentCasecnt > 0
               ORDER BY ReplenishmentSeverity DESC

               IF @@ROWCOUNT = 0
               BEGIN
                  BREAK
               END

               IF @b_debug = 1
               BEGIN
                  Print 'Working on @n_CurrentSeverity:' + dbo.fnc_RTrim(@n_CurrentSeverity)
               END 

               /* Now - for this priority, this severity - find the next storer row */
               /* that matches */
               SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
               @c_CurrentLOC = SPACE(10)
               WHILE (1=1) -- while 3
               BEGIN
                  IF dbo.fnc_RTrim(@c_zone11) IS NOT NULL AND dbo.fnc_RTrim(@c_zone11) <> ''
                  BEGIN
                     SELECT TOP 1 @c_CurrentStorer = StorerKey
                     FROM #TempSKUxLOC
                     WHERE StorerKey > @c_CurrentStorer
                     AND ReplenishmentSeverity = @n_CurrentSeverity
                     AND ReplenishmentPriority = @c_CurrentPriority
                     AND StorerKey Like @c_zone11
                     AND (Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  --NJOW01
                     ORDER BY StorerKey
                  END
                  ELSE
                  BEGIN
                     SELECT TOP 1 @c_CurrentStorer = StorerKey
                     FROM #TempSKUxLOC
                     WHERE StorerKey > @c_CurrentStorer
                     AND ReplenishmentSeverity = @n_CurrentSeverity
                     AND ReplenishmentPriority = @c_CurrentPriority
                     AND (Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  --NJOW01
                     ORDER BY StorerKey
                  END 
               
                  IF @@ROWCOUNT = 0
                  BEGIN
                     BREAK
                  END

                  IF @b_debug = 1
                  BEGIN
                     Print 'Working on @c_CurrentStorer:' + dbo.fnc_RTrim(@c_CurrentStorer)
                  END 
                  /* Now - for this priority, this severity - find the next SKU row */
                  /* that matches */
                  SELECT @c_CurrentSKU = SPACE(20),
                  @c_CurrentLOC = SPACE(10)
                  WHILE (1=1) -- while 4
                  BEGIN
                     SELECT TOP 1 @c_CurrentStorer = StorerKey ,
                           @c_CurrentSKU = SKU,
                           @c_CurrentLOC = LOC,
                           @n_currentFullCase = ReplenishmentCasecnt
                     FROM #TempSKUxLOC
                     WHERE SKU > @c_CurrentSKU 
                     AND StorerKey = @c_CurrentStorer
                     AND ReplenishmentSeverity = @n_CurrentSeverity
                     AND ReplenishmentPriority = @c_CurrentPriority
                     ORDER BY SKU
                     IF @@ROWCOUNT = 0
                     BEGIN

                        BREAK
                     END
                  
                     IF @b_debug = 1
                     BEGIN
                        Print 'Working on @c_CurrentSKU:' + dbo.fnc_RTrim(@c_CurrentSKU) + ' @c_CurrentLOC:' + dbo.fnc_RTrim(@c_CurrentLOC) 
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
                            @b_DoneCheckOverAllocatedLots = 0,
                            @n_SerialNo = 0

                     CREATE TABLE #LOT (SerialNo   int IDENTITY(1,1),
                                   Lot        NVARCHAR(10), 
                                   SortDate   NVARCHAR(20) NULL) 
               
                     WHILE (1=1)  -- while 5
                     BEGIN
                        SELECT @c_PickCode = PickCode
                        FROM  SKU (NOLOCK)
                        WHERE StorerKey = @c_CurrentStorer
                        AND   SKU = @c_CurrentSKU

                        /* See if there are any lots where the QTY is overalLOCated... */
                        /* if Yes then uses this lot first... */
                        -- That means that the last try at this section of code was successful therefore try again.
                        IF @b_DoneCheckOverAllocatedLots = 0
                        BEGIN
                           SELECT TOP 1  @c_fromlot2 = LOTxLOCxID.LOT,
                                  @d_lottable05 = LOTATTRIBUTE.Lottable05
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot2 --or LOTxLOCxID.LOT < (@c_fromlot2))
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_CurrentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LocationFlag <> "DAMAGE"
                           AND LOC.LocationFlag <> "HOLD"
                           AND  LOC.Status <> "HOLD"
                           AND ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) - LOTxLOCxID.qty) > 0 -- SOS 6217
                           AND LOTxLOCxID.LOC = @c_CurrentLOC
                           AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                           AND LOTxLOCxID.STORERKEY = LOTATTRIBUTE.STORERKEY
                           AND LOTxLOCxID.SKU = LOTATTRIBUTE.SKU
                           AND LOC.Facility = @c_zone01
                           ORDER BY LOTxLOCxID.LOT

                           IF @@ROWCOUNT = 0
                           BEGIN
                              SELECT @b_DoneCheckOverAllocatedLots = 1
                              IF @b_debug = 1
                              BEGIN
                                 Print 'Not Lot Found! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' @c_CurrentLOC: ' + dbo.fnc_RTrim(@c_CurrentLOC) + ' @c_fromlot2: ' + ISNULL(dbo.fnc_RTrim(@c_fromlot2), '')
                              END
                              SELECT @c_fromlot = SPACE(10)
                              SELECT @d_lottable05 = SPACE(10)
                           END
                           ELSE
                           BEGIN
                              SELECT @c_fromlot = @c_fromlot2
                           END
                        END -- done checkoverallocatedlots = 0

                        /* End see if there are any lots where the QTY is overalLOCated... */

                        /* If there are not lots overallocated in the candidate Location, simply pull lots into the Location by lot # */
                        IF @b_DoneCheckOverAllocatedLots = 1
                        BEGIN
                           /* SELECT any lot if no lot was over alLOCated */
                           IF dbo.fnc_RTrim(@c_PickCode) IS NOT NULL AND dbo.fnc_RTrim(@c_PickCode) <> ''
                           BEGIN
                              INSERT INTO #LOT (Lot, SortDate)
                           
                              EXEC(@c_PickCode + " N'" + @c_CurrentStorer + "',"
                                               + " N'" + @c_CurrentSKU + "',"
                                               + " N'" + @c_CurrentLOC + "',"
                                               + " N'" + @c_zone01 + "',"
   --                                            + " '" + @d_lottable05 + "',"
                                               + " N'" + @c_fromlot2 + "'" )
                              IF @b_debug = 1
                              BEGIN
                              print "EXEC " + @c_PickCode + " N'" + dbo.fnc_RTrim(@c_CurrentStorer) + "',"
                                               + " N'" + dbo.fnc_RTrim(@c_CurrentSKU) + "',"
                                               + " N'" + dbo.fnc_RTrim(@c_CurrentLOC) + "',"
                                               + " N'" + dbo.fnc_RTrim(@c_zone01) + "',"
                                               + " N'" + dbo.fnc_RTrim(@c_fromlot2) + "'"
                              END 
                           END
                           ELSE 
                           BEGIN
                              INSERT INTO #LOT (Lot, SortDate)
                              SELECT DISTINCT LOTxLOCxID.LOT, LOTTABLE05
                              FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                              WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
                              AND LOTxLOCxID.SKU = @c_CurrentSKU
                              AND LOTxLOCxID.LOC = LOC.LOC
                              AND LOC.LocationFlag <> "DAMAGE"
                              AND LOC.LocationFlag <> "HOLD"
                              AND LOC.Status <> "HOLD"
                              AND LOC.Facility = @c_zone01
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC
                              AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                              AND LOTxLOCxID.LOT <> ISNULL(@c_fromlot2, '')
                              AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
                              ORDER BY LOTxLOCxID.LOT
                           END
                        
                           --NJOW01
                           DELETE #LOT
                           FROM #LOT 
                           JOIN LOT (NOLOCK) ON #LOT.Lot = LOT.Lot
                           WHERE LOT.Status = 'HOLD'

                           IF (SELECT COUNT(*) FROM #LOT) = 0
                           BEGIN
                              IF @b_debug = 1
                                 print 'Not Lot Available! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' LOC:' + dbo.fnc_RTrim(@c_CurrentLOC)
                              BREAK
                           END
                           ELSE
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 print '*** Lot picked from LOTxLOCxID : ' + dbo.fnc_RTrim(@c_fromlot)
                              END
                           END 
                           IF @b_debug = 1
                           BEGIN
                              print '*** Selected Lot: ' + dbo.fnc_RTrim(@c_fromlot)
                           END
                           SELECT @b_DoneCheckOverAllocatedLots = 2
                        END -- IF @b_DoneCheckOverAllocatedLots = 1
                        ELSE 
                        IF @b_DoneCheckOverAllocatedLots = 0
                        BEGIN
                           SELECT @b_DoneCheckOverAllocatedLots = 1
                        END 

                        IF @b_DoneCheckOverAllocatedLots = 2 
                        BEGIN
    
                           SELECT TOP 1 @c_FromLot = LOT,
                                  @n_SerialNo = SerialNo 
                           FROM   #LOT
                           WHERE  SerialNo > @n_SerialNo 
                           Order by SerialNo
                           
                           IF @@ROWCOUNT = 0 
                           BEGIN
     
                           IF @b_debug = 1
                              Print 'Not Lot Available! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' LOC:' + dbo.fnc_RTrim(@c_CurrentLOC)
                              BREAK
                           END
                           ELSE
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 Print '*** Lot picked from LOTxLOCxID=' + dbo.fnc_RTrim(@c_fromlot)
                              END
                           END 
                           IF @b_debug = 1
                           BEGIN
                              Print 'SELECTed Lot =' + @c_fromlot
                           END
                        END
                        SELECT @c_FromLOC = SPACE(10)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         WHILE (1=1 AND @n_remainingqty > 0)
                        BEGIN

                        SELECT TOP 1 @c_FromLOC = LOTxLOCxID.LOC
                        FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                        WHERE LOT = @c_fromlot
                        AND LOTxLOCxID.LOC = LOC.LOC
                        AND LOTxLOCxID.LOC > @c_FromLOC
                        AND StorerKey = @c_CurrentStorer
                        AND SKU = @c_CurrentSKU
                        AND LOTxLOCxID.LOC = LOC.LOC
                        AND LOC.LocationFlag <> "DAMAGE"
                        AND LOC.LocationFlag <> "HOLD"
                        AND LOC.Status <> "HOLD"
                        AND LOC.Facility = @c_zone01
                        AND LOTxLOCxID.qty - qtypicked - QtyAllocated > 0
                        AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
                        AND LOTxLOCxID.LOC <> @c_CurrentLOC
                        ORDER BY LOTxLOCxID.LOC
                        
                        IF @@ROWCOUNT = 0
                        BEGIN
                           IF @b_debug = 1
                           BEGIN
                              Print 'No LOC Selected!'
                           END
                           BREAK
                        END

                        IF @b_debug = 1
                        BEGIN
                           Print 'Location Selected = ' + @c_FromLOC
                        END

                        SELECT @c_fromid = replicate('Z',18)
                        WHILE (1=1 AND @n_remainingqty > 0)
                        BEGIN
                           SELECT TOP 1 @c_fromid = ID,
                           @n_OnHandQty = LOTxLOCxID.QTY - QTYPICKED - QtyAllocated
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                           WHERE LOT = @c_fromlot
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOTxLOCxID.LOC = @c_FromLOC
                           AND id < @c_fromid
                           AND StorerKey = @c_CurrentStorer
                           AND SKU = @c_CurrentSKU
                           AND LOC.LocationFlag <> "DAMAGE"
                           AND LOC.LocationFlag <> "HOLD"
                           AND LOC.Status <> "HOLD"
                           AND LOC.Facility = @c_zone01
                           AND LOTxLOCxID.qty - qtypicked - QtyAllocated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
                           AND LOTxLOCxID.LOC <> @c_CurrentLOC
                           ORDER BY ID DESC
                           IF @@ROWCOUNT = 0
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 Print 'Stop because No Pallet Found! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_FromLOC
                                 + ' From ID = ' + @c_fromid
                              END

                              BREAK
                           END

                           IF @b_debug = 1
                           BEGIN
                              Print 'ID SELECTed:'+ @c_fromid + ' Onhandqty:' + cast(@n_onhandqty as NVARCHAR(10))
                           END
                           /* We have a cANDidate FROM record */
                           /* Verify that the cANDidate ID is not on HOLD */
                           /* We could have done this in the SQL statements above */
                           /* But that would have meant a 5-way join.             */
                           /* SQL SERVER seems to work best on a maximum of a     */
                           /* 4-way join.                                        */
                           IF EXISTS(SELECT * FROM ID (NOLOCK) WHERE ID = @c_fromid
                           AND STATUS = "HOLD")
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 Print 'Stop because Location Status = HOLD! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU + ' ID = ' + @c_fromid
                              END
                              BREAK -- Get out of loop, so that next cANDidate can be evaluated
                           END
                           /* Verify that the from Location is not overalLOCated in SKUxLOC */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                                    WHERE StorerKey = @c_CurrentStorer
                                    AND SKU = @c_CurrentSKU
                                    AND LOC = @c_FromLOC
                                    AND QTYEXPECTED > 0
                                    )
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 Print 'Stop because Qty Expected > 0! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
                              END
                              BREAK -- Get out of loop, so that next cANDidate can be evaluated
                           END
                           /* Verify that the FROM Location is not the */
                           /* PIECE PICK Location for this product.    */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                                    WHERE StorerKey = @c_CurrentStorer
                                    AND SKU = @c_CurrentSKU
                                    AND LOC = @c_FromLOC
                                    AND LocationType = "PICK"
                                    )
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 Print 'Stop because Location Type = PICK! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
                              END
                              BREAK -- Get out of loop, so that next cANDidate can be evaluated
                           END
                           /* Verify that the FROM Location is not the */
                           /* CASE PICK Location for this product.     */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                                       WHERE StorerKey = @c_CurrentStorer
                                       AND SKU = @c_CurrentSKU
                                       AND LOC = @c_FromLOC
                                       AND LocationType = "CASE"
                                       )
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 Print 'Stop because Location Type = CASE! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU
                              END
                              BREAK -- Get out of loop, so that next cANDidate can be evaluated
                           END
                              /* At this point, get the available qty from */
                              /* the SKUxLOC record.                  */
                              /* If it's less than what was taken from the */
                              /* LOTxLOCxID record, then use it.           */
                              /*
                              SELECT @n_SKULocAvailableQty = QTY - QtyAllocated - QTYPICKED
                              FROM SKUxLOC (NOLOCK) 
                              WHERE StorerKey = @c_CurrentStorer
                              AND SKU = @c_CurrentSKU
                            AND LOC = @c_FromLOC
                              */
                              /*-- get from LOTxLOCxID. coz if there is a 2 lots sharing 1 loc, it will be wrong, for above statement this happens for wave replenishments... a group of orders
                              */
--                               SELECT @n_skulocavailableQty = Qty - QtyAllocated - QtyPicked
--                               FROM LOTxLOCxID (NOLOCK)
--                               WHERE Storerkey = @c_currentstorer
--                               AND SKU = @c_CurrentSKU 
--                               AND LOC = @c_FromLOC 
--                               AND ID  = @c_fromid 
--                               AND LOT = @c_fromlot 
--                               IF @b_debug = 1
--                               BEGIN
--                                  SELECT '@c_fromlot' = @c_fromlot,  '@c_FromLOC', @c_FromLOC, 'SKULOCAvailableQty' = @n_SKULocAvailableQty , '@n_OnHandQty' = @n_OnHandQty
--                               END
-- 
--                               IF @n_SKULocAvailableQty < @n_OnHandQty
--                               BEGIN
--                                  SELECT @n_OnHandQty = @n_SKULocAvailableQty
--                               END
                              /* How many cases can I get from this record? */
                           SELECT @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullCase)
--                               IF @n_PossibleCases = 0
--                               BEGIN
--                                  SELECT @n_OnHandQty = 0
-- 
--                                  IF @b_debug = 1
--                                  BEGIN
--                                     SELECT 'Qty < then full case. Qty =' + CAST(@n_OnHandQty as NVARCHAR(4)) + ' Full Case = ' + CAST(@n_CurrentFullCase as NVARCHAR(4)) 
--                                  END
-- 
--                                  BREAK 
--                               END 

                           IF @b_debug = 1
                           BEGIN
                              Print '@n_OnHandQty  = ' + cast(@n_OnHandQty as NVARCHAR(10))  + ' @n_RemainingQty  =' + cast(@n_RemainingQty as NVARCHAR(10))
                              Print '@n_possiblecases =' + cast(@n_possiblecases as NVARCHAR(10)) + ' @n_currentFullCase = ' + cast(@n_currentFullCase as NVARCHAR(10))
                           END
                           /* How many do we take? */
                           IF @n_OnHandQty > @n_RemainingQty
                           BEGIN
                              -- Modify by SHONG for full carton only
                              SELECT @n_FromQty = @n_RemainingQty
                              SELECT @n_RemainingQty = 0
                              /* -- minus off the qtyexpected for a lot (in to loc)
                              SELECT @n_qtytaken = QtyExpected
                              FROM LOTxLOCxID (NOLOCK)
                              WHERE Storerkey = @c_currentstorer
                              AND SKU = @c_CurrentSKU
                              AND LOC = @c_CurrentLOC
                              AND LOT = @c_fromlot
                              SELECT @n_remainingQty = @n_remainingQty - @n_qtytaken
                              */
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
                                 print 'Checking possible cases AND current full case available - @n_RemainingQty > @n_FromQty'
                                 Print '@n_possiblecases:' + cast(@n_possiblecases as NVARCHAR(10)) + ' @n_currentFullCase:' + cast(@n_currentFullCase as NVARCHAR(10)) + '@n_FromQty:' + cast(@n_FromQty as NVARCHAR(10))
                                 END
                              END
                              /*
                              IF @n_FromQty = 0
                              BEGIN
                                 SELECT @n_FromQty = 
                                 LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYEXPECTED
                                 FROM LOTxLOCxID (NOLOCK)
                                 WHERE LOTxLOCxID.LOC = @c_FromLOC
                                 AND LOTxLOCxID.LOT = @c_fromlot
                                 AND LOTxLOCxID.SKU =@c_CurrentSKU
                                 AND LOTxLOCxID.STORERKEY = @c_currentstorer
                              END
                              */

                              IF @n_FromQty > 0
                              BEGIN
                                 SELECT @c_Packkey = PACK.PackKey,
                                          @c_UOM = PACK.PackUOM3,
                                          @c_CtnUOM = PACK.PackUOM1,
                                          @c_InnerUOM = PACK.PackUOM2
                                 FROM   SKU (NOLOCK), PACK (NOLOCK)
                                 WHERE  SKU.PackKey = PACK.Packkey
                                 AND    SKU.StorerKey = @c_CurrentStorer
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
                              IF @c_fromid = '' OR @c_fromid IS NULL OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromId)) = ''
                              BEGIN
                                 -- SELECT @n_remainingqty=0
                                 BREAK
                              END
                           END -- SCAN LOT for ID
                        END -- SCAN LOT for LOC
                     END -- SCAN LOT FOR LOT
                     DROP TABLE #LOT
                  END -- FOR SKU
               END -- FOR STORER
            END
         END  -- (WHILE 1=1 on SKUxLOC FOR PRIORITY )
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
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to get REPLENISHKEY. (nsp_ReplenishmentRpt_BatchRefill_05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into Replenishment table failed. (nsp_ReplenishmentRpt_BatchRefill_05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishmentRpt_BatchRefill_05'
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
   END                                                               --(Wan01)
   --(Wan01) - START
   IF @c_FuncType = 'G'                                              
   BEGIN                                                             
       GOTO QUIT_SP
   END                                                              
   --(Wan01) - END
   IF ( @c_zone02 = 'ALL')
   BEGIN
      --TLTING01      
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, L2.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, R.AddDate, R.AddWho, R.EditDate, R.EditWho, 
      (LT.Qty - LT.QtyAllocated - LT.QtyPicked) As QtyAvailable, 
      LA.Lottable02, LA.Lottable04, PACK.PACKUOM2, PACK.INNERPACK, SKL.QtyExpected, L2.LocAisle
      FROM  REPLENISHMENT R (NOLOCK), SKU (NOLOCK), LOC L1 (NOLOCK), PACK (NOLOCK),  LOC L2 (nolock), LOTxLOCxID LT (nolock) , LOTATTRIBUTE LA (NOLOCK), SKUxLOC SKL (NOLOCK)
      WHERE SKU.Sku = R.Sku
      AND  SKU.StorerKey = R.StorerKey
      AND  L1.Loc = R.ToLoc
      AND  L2.Loc = R.FromLoc
      AND  LT.Lot = R.Lot
      AND  LT.Loc = R.FromLoc
      AND  LT.ID = R.ID
      AND  LT.LOT = LA.LOT
      AND  LT.SKU = LA.SKU
      AND  LT.STORERKEY = LA.STORERKEY
      AND  SKL.STORERKEY = SKU.Storerkey
      AND  SKL.SKU = SKU.Sku
      AND  SKL.LOC = L1.LOC
      AND  SKU.PackKey = PACK.PackKey
      AND  R.confirmed = 'N'
      AND  L1.Facility = @c_zone01
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  --NJOW01
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)
      ORDER BY L1.PutawayZone, R.FromLoc, R.SKU 
   END
   ELSE
   BEGIN
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, L2.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, R.AddDate, R.AddWho, R.EditDate, R.EditWho, 
      (LT.Qty - LT.QtyAllocated - LT.QtyPicked) As QtyAvailable, 
      LA.Lottable02, LA.Lottable04, PACK.PACKUOM2, PACK.INNERPACK, SKL.QtyExpected, L2.LocAisle
      FROM  REPLENISHMENT R, SKU (NOLOCK), LOC L1 (NOLOCK), LOC L2 (nolock) , PACK (NOLOCK) , LOTxLOCxID LT(nolock), LOTATTRIBUTE LA (NOLOCK), SKUxLOC SKL (NOLOCK)
      WHERE SKU.Sku = R.Sku
      AND   SKU.StorerKey = R.StorerKey
      AND   L1.Loc = R.ToLoc
      AND   L2.Loc = R.FromLoc
      AND   LT.Lot = R.Lot
      AND   LT.Loc = R.FromLoc
      AND   LT.ID = R.ID
      AND   LT.LOT = LA.LOT
      AND   LT.SKU = LA.SKU
      AND   LT.STORERKEY = LA.STORERKEY
      AND   SKL.STORERKEY = SKU.Storerkey
      AND   SKL.SKU = SKU.Sku
      AND   SKL.LOC = L1.LOC
      AND   SKU.PackKey = PACK.PackKey
      AND   R.confirmed = 'N'
      AND   L1.Facility = @c_zone01
      AND   L1.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  --NJOW01
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)
      ORDER BY L1.PutawayZone, R.FromLoc, R.SKU 
   END
   QUIT_SP:                                                          --(Wan01)
END

GO