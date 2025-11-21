SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReplenishmentRpt_BatchRefill_21                */
/* Creation Date: 07-Oct-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15420 - MYSûKFMYûAdd Lottable01-05 as Parameter for Wave*/
/*          Replenishment                                               */
/*          Copy from nsp_ReplenishmentRpt_BatchRefill_03 and modify    */
/*                                                                      */
/* Called By: r_replenishment_report21                                  */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/
CREATE PROC  [dbo].[isp_ReplenishmentRpt_BatchRefill_21]
               @c_zone01           NVARCHAR(20)
,              @c_zone02           NVARCHAR(20)
,              @c_zone03           NVARCHAR(20)
,              @c_zone04           NVARCHAR(20)
,              @c_zone05           NVARCHAR(20)
,              @c_zone06           NVARCHAR(20)
,              @c_zone07           NVARCHAR(20)
,              @c_zone08           NVARCHAR(20)
,              @c_zone09           NVARCHAR(20)
,              @c_zone10           NVARCHAR(500)
,              @c_zone11           NVARCHAR(500)
,              @c_zone12           NVARCHAR(20)
,              @c_storerkey        NVARCHAR(15)
,              @c_ReplGrp          NVARCHAR(30) = 'ALL'
,              @c_Functype         NCHAR(1) = ''
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
   ,               @n_starttcnt   int

   DECLARE @b_debug INT,
   @c_Packkey NVARCHAR(10),
   @c_UOM     NVARCHAR(10),
   @n_qtytaken INT,
   @n_SerialNo INT,
   @n_ROWREF   INT,
   @n_Rowcnt   INT,
   @n_ReplenishmentKey INT,
   @c_SQLStatement     NVARCHAR(MAX),
   @c_ExecArguments    NVARCHAR(MAX)

   DECLARE @b_success INT,
           @n_err     INT,
           @c_errmsg  NVARCHAR(255)   
            
   SELECT @n_continue=1, @b_debug = 0
   SELECT @n_starttcnt=@@TRANCOUNT
   /*
   IF @c_zone12 <> '' AND ISNUMERIC(@c_zone12) = 1
      SELECT @b_debug = CAST( @c_zone12 AS int)

   IF @c_zone10 = ''
      SELECT @c_zone10 = 'ZZZZZZZZZZ'
   IF @c_zone12 = ''
      SELECT @c_zone12 = 'ZZZZZZZZZZ'*/
      
   IF @c_zone11 IS NOT NULL AND @c_zone11 <> '' AND ISDATE(@c_zone11) = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 66000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Zone11 must be DATETIME format. (isp_ReplenishmentRpt_BatchRefill_21)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO R_ERROR
   END  
      
   IF @c_zone12 IS NOT NULL AND @c_zone12 <> '' AND ISDATE(@c_zone12) = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 66005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Zone12 must be DATETIME format. (isp_ReplenishmentRpt_BatchRefill_21)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO R_ERROR
   END  

   DECLARE @c_priority  NVARCHAR(5)
   
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END

   IF @c_FuncType IN ( '','G' )                                    
   BEGIN                                                          
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

         DECLARE @c_PickCode NVARCHAR(10)

         SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
         @c_CurrentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),
         @n_CurrentFullCase = 0   , @n_CurrentSeverity = 9999999 ,
         @n_FromQty = 0, @n_remainingqty = 0, @n_PossibleCases = 0,
         @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,
         @n_limitrecs = 5
      
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
                     ELSE QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))
                  END,
            SKUxLOC.StorerKey,
            SKUxLOC.SKU,
            SKUxLOC.LOC,
            ReplenishmentCasecnt = 
               CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt
                  ELSE 1
               END
            FROM SKUxLOC (NOLOCK), LOC (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
            WHERE SKUxLOC.LOC = LOC.LOC
            AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
            AND  LOC.FACILITY = @c_Zone01
            AND (SKUXLOC.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')          
            --AND  SKUXLOC.SKU BETWEEN @c_zone09 AND @c_zone10 
            --AND  LOC.LocAisle BETWEEN @c_zone11 AND @c_zone12 
            AND  SKUxLOC.StorerKey = SKU.StorerKey
            AND  SKUxLOC.SKU = SKU.SKU
            AND  SKU.PackKey = PACK.PACKKey
            AND  EXISTS( SELECT 1 FROM SKUxLOC SL (NOLOCK) WHERE SL.StorerKey = SKUxLOC.StorerKey 
                          AND SL.SKU = SKUxLOC.SKU AND SL.Qty - SL.QtyPicked - SL.QtyAllocated > 0 
                          AND SL.LOC <> SKUxLOC.LOC )
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
                     ELSE QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))
                  END,
            SKUxLOC.StorerKey,
            SKUxLOC.SKU,
            SKUxLOC.LOC,
            ReplenishmentCasecnt =  
               CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt
                  ELSE 1
               END
            FROM SKUxLOC (NOLOCK), LOC (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
            WHERE SKUxLOC.LOC = LOC.LOC
            AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
            AND  LOC.FACILITY = @c_Zone01
            AND  (SKUXLOC.Storerkey = @c_storerkey OR @c_storerkey = 'ALL') 
            --AND  SKUXLOC.SKU BETWEEN @c_zone09 AND @c_zone10 
            --AND  LOC.LocAisle BETWEEN @c_zone11 AND @c_zone12 
            AND  SKUxLOC.StorerKey = SKU.StorerKey
            AND  SKUxLOC.SKU = SKU.SKU
            AND  SKU.PackKey = PACK.PACKKey
            AND  EXISTS( SELECT 1 FROM SKUxLOC SL (NOLOCK) WHERE SL.StorerKey = SKUxLOC.StorerKey 
                          AND SL.SKU = SKUxLOC.SKU AND SL.Qty - SL.QtyPicked - SL.QtyAllocated > 0 
                          AND SL.LOC <> SKUxLOC.LOC )
            AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07)
         END 

         IF @b_debug = 1
         BEGIN
            SELECT * FROM #TEMPSKUxLOC (NOLOCK)
         END

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
               SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
               @c_CurrentLOC = SPACE(10)
               WHILE (1=1) -- while 3
               BEGIN
                     SET ROWCOUNT 1
                     SELECT @c_CurrentStorer = StorerKey
                     FROM #TempSKUxLOC
                     WHERE StorerKey > @c_CurrentStorer
                     AND ReplenishmentSeverity = @n_CurrentSeverity
                     AND ReplenishmentPriority = @c_CurrentPriority
                     AND (Storerkey = @c_storerkey OR @c_storerkey = 'ALL')
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
                  SELECT @c_CurrentSKU = SPACE(20),
                  @c_CurrentLOC = SPACE(10)
                  WHILE (1=1) -- while 4
                  BEGIN
                     SET ROWCOUNT 1
                     SELECT @c_CurrentStorer = StorerKey ,
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
                        SET ROWCOUNT 0
                        BREAK
                     END
                     SET ROWCOUNT 0
                  
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
                           SET ROWCOUNT 1

                           SELECT @c_fromlot2 = LOTxLOCxID.LOT 
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK)   
                           WHERE LOTxLOCxID.LOT > @c_fromlot2 --or LOTxLOCxID.LOT < (@c_fromlot2))
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_CurrentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LocationFlag <> 'DAMAGE'
                           AND LOC.LocationFlag <> 'HOLD'
                           AND  LOC.Status <> 'HOLD'
                           AND ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) - LOTxLOCxID.qty) > 0 
                           AND LOTxLOCxID.LOC = @c_CurrentLOC
                           AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                           AND LOTxLOCxID.STORERKEY = LOTATTRIBUTE.STORERKEY
                           AND LOTxLOCxID.SKU = LOTATTRIBUTE.SKU
                           AND LOC.Facility = @c_zone01
                           AND (LOTXLOCXID.Storerkey = @c_storerkey OR @c_storerkey = 'ALL') 
                           AND LOTATTRIBUTE.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_zone08),'') = '' THEN LOTATTRIBUTE.Lottable01 ELSE @c_zone08 END     
                           AND LOTATTRIBUTE.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_zone09),'') = '' THEN LOTATTRIBUTE.Lottable02 ELSE @c_zone09 END 
                           AND LOTATTRIBUTE.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_zone10),'') = '' THEN LOTATTRIBUTE.Lottable03 ELSE @c_zone10 END  
                           AND LOTATTRIBUTE.Lottable04 = CASE WHEN ISNULL(RTRIM(@c_zone11),'') = '' THEN LOTATTRIBUTE.Lottable04 ELSE @c_zone11 END  
                           AND LOTATTRIBUTE.Lottable05 = CASE WHEN ISNULL(RTRIM(@c_zone12),'') = '' THEN LOTATTRIBUTE.Lottable05 ELSE @c_zone12 END 
                           --AND LOTxLOCxID.SKU BETWEEN @c_zone09 AND @c_zone10 
                           AND LOT.LOT = LotxLocxID.Lot        
                           AND Lot.Status <> 'HOLD'            
                           AND LOTATTRIBUTE.Lottable01 <> 'QI' 
                           AND LOTATTRIBUTE.Lottable01 <> 'BLOCK' 

                           IF @@ROWCOUNT = 0
                           BEGIN
                              SELECT @b_DoneCheckOverAllocatedLots = 1
                              SET ROWCOUNT 0
                              IF @b_debug = 1
                              BEGIN
                                 Print 'Not Lot Found! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' @c_CurrentLOC: ' + dbo.fnc_RTrim(@c_CurrentLOC) + ' @c_fromlot2: ' + ISNULL(dbo.fnc_RTrim(@c_fromlot2), '')
                              END
                              SELECT @c_fromlot = SPACE(10)
                           END
                           ELSE
                           BEGIN
                              SELECT @c_fromlot = @c_fromlot2
                           END
                        END -- done checkoverallocatedlots = 0

                        /* End see if there are any lots where the QTY is overalLOCated... */
                        SET ROWCOUNT 0
                        /* If there are not lots overallocated in the candidate Location, simply pull lots into the Location by lot # */
                        IF @b_DoneCheckOverAllocatedLots = 1
                        BEGIN
                           /* SELECT any lot if no lot was over alLOCated */
                           IF dbo.fnc_RTrim(@c_PickCode) IS NOT NULL AND dbo.fnc_RTrim(@c_PickCode) <> ''
                           BEGIN
                              INSERT INTO #LOT (Lot, SortDate)
                           
                              EXEC(@c_PickCode + ' N''' + @c_CurrentStorer + ''','
                                               + ' N''' + @c_CurrentSKU + ''','
                                               + ' N''' + @c_CurrentLOC + ''','
                                               + ' N''' + @c_zone01 + ''','
                                               + ' N''' + @c_fromlot2 + '''' )
                              IF @b_debug = 1
                              BEGIN
                                 print 'EXEC ' + @c_PickCode + ' N''' + dbo.fnc_RTrim(@c_CurrentStorer) + ''','
                                               + ' N''' + dbo.fnc_RTrim(@c_CurrentSKU) + ''','
                                               + ' N''' + dbo.fnc_RTrim(@c_CurrentLOC) + ''','
                                               + ' N''' + dbo.fnc_RTrim(@c_zone01) + ''','
                                               + ' N''' + dbo.fnc_RTrim(@c_fromlot2) + ''''
                              END 
                           END
                           ELSE 
                           BEGIN
                              INSERT INTO #LOT (Lot, SortDate)
                              SELECT DISTINCT LOTxLOCxID.LOT, LOTTABLE05
                              FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK)      
                              WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
                              AND LOTxLOCxID.SKU = @c_CurrentSKU
                              AND LOTxLOCxID.LOC = LOC.LOC
                              AND LOC.LocationFlag <> 'DAMAGE'
                              AND LOC.LocationFlag <> 'HOLD'
                              AND LOC.Status <> 'HOLD'
                              AND LOC.Facility = @c_zone01
                              AND (LOTXLOCXID.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')
                              AND LOTATTRIBUTE.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_zone08),'') = '' THEN LOTATTRIBUTE.Lottable01 ELSE @c_zone08 END     
                              AND LOTATTRIBUTE.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_zone09),'') = '' THEN LOTATTRIBUTE.Lottable02 ELSE @c_zone09 END 
                              AND LOTATTRIBUTE.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_zone10),'') = '' THEN LOTATTRIBUTE.Lottable03 ELSE @c_zone10 END  
                              AND LOTATTRIBUTE.Lottable04 = CASE WHEN ISNULL(RTRIM(@c_zone11),'') = '' THEN LOTATTRIBUTE.Lottable04 ELSE @c_zone11 END  
                              AND LOTATTRIBUTE.Lottable05 = CASE WHEN ISNULL(RTRIM(@c_zone12),'') = '' THEN LOTATTRIBUTE.Lottable05 ELSE @c_zone12 END 
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC
                              AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                              AND LOTxLOCxID.LOT <> ISNULL(@c_fromlot2, '')
                              AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
                              AND LOT.LOT = LotxLocxID.Lot        
                               AND Lot.Status <> 'HOLD'           
                              ORDER BY LOTxLOCxID.LOT
                           END

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
                           SET ROWCOUNT 1

                           /*SELECT @c_FromLot = LOT,
                                  @n_SerialNo = SerialNo 
                           FROM   #LOT
                           WHERE  SerialNo > @n_SerialNo*/
                                                
                           SELECT @c_FromLot = LO.LOT,
                                  @n_SerialNo = LO.SerialNo 
                           FROM   #LOT LO 
                           JOIN LOTATTRIBUTE LA (NOLOCK) ON (LO.Lot = LA.Lot)
                           WHERE  LO.SerialNo > @n_SerialNo
                           AND LA.Lottable01 <> 'QI' 
                           AND LA.Lottable01 <> 'BLOCK' 
                           AND LA.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_zone08),'') = '' THEN LA.Lottable01 ELSE @c_zone08 END     
                           AND LA.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_zone09),'') = '' THEN LA.Lottable02 ELSE @c_zone09 END 
                           AND LA.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_zone10),'') = '' THEN LA.Lottable03 ELSE @c_zone10 END  
                           AND LA.Lottable04 = CASE WHEN ISNULL(RTRIM(@c_zone11),'') = '' THEN LA.Lottable04 ELSE @c_zone11 END  
                           AND LA.Lottable05 = CASE WHEN ISNULL(RTRIM(@c_zone12),'') = '' THEN LA.Lottable05 ELSE @c_zone12 END 
                              
                           ORDER BY LO.SerialNo

                           IF @@ROWCOUNT = 0 
                           BEGIN
                              SET ROWCOUNT 0 
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
                           SET ROWCOUNT 0 
                        END

                        SELECT @c_FromLOC = SPACE(10)
                        WHILE (1=1 AND @n_remainingqty > 0)
                        BEGIN
                           SET ROWCOUNT 1

                           SELECT @c_FromLOC = LOTxLOCxID.LOC
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOT (NOLOCK)        
                           WHERE LOTxLOCxID.LOT = @c_fromlot
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOTxLOCxID.LOC > @c_FromLOC
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_CurrentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LocationFlag <> 'DAMAGE'
                           AND LOC.LocationFlag <> 'HOLD'
                           AND LOC.Status <> 'HOLD'
                           AND LOC.Facility = @c_zone01
                           --AND LOTxLOCxID.Storerkey = @c_zone08 
                           AND (LOTXLOCXID.Storerkey = @c_storerkey OR @c_storerkey = 'ALL') 
                           --AND LOTxLOCxID.SKU BETWEEN @c_zone09 AND @c_zone10 
                           AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.QtyAllocated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
                           AND LOTxLOCxID.LOC <> @c_CurrentLOC
                           AND LOT.LOT = LotxLocxID.Lot        
                           AND Lot.Status <> 'HOLD'            
                        
                           ORDER BY LOTxLOCxID.LOC
                           IF @@ROWCOUNT = 0
                           BEGIN
                              SET ROWCOUNT 0
                              IF @b_debug = 1
                              BEGIN
                                 Print 'No LOC Selected!'
                              END
                              BREAK
                           END
                           SET ROWCOUNT 0
                           IF @b_debug = 1
                           BEGIN
                              Print 'Location Selected = ' + @c_FromLOC
                           END

                           SELECT @c_fromid = replicate('Z',18)
                           WHILE (1=1 AND @n_remainingqty > 0)
                           BEGIN
                              SET ROWCOUNT 1
                              
                              SELECT @c_fromid = ID,
                              @n_OnHandQty = LOTxLOCxID.QTY - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyAllocated
                              FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK) , LOT (NOLOCK)       
                              WHERE LOTxLOCxID.LOT = @c_fromlot
                              AND LOTxLOCxID.LOC = LOC.LOC
                              AND LOTxLOCxID.LOC = @c_FromLOC
                              AND LOTxLOCxID.id < @c_fromid
                              AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                              AND LOTxLOCxID.SKU = @c_CurrentSKU
                              AND LOC.LocationFlag <> 'DAMAGE'
                              AND LOC.LocationFlag <> 'HOLD'
                              AND LOC.Status <> 'HOLD'
                              AND LOC.Facility = @c_zone01
                              AND (LOTXLOCXID.Storerkey = @c_storerkey OR @c_storerkey = 'ALL') 
                              --AND LOTxLOCxID.SKU BETWEEN @c_zone09 AND @c_zone10 
                              AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.QtyAllocated > 0
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC
                              AND LOT.LOT = LotxLocxID.Lot        
                              AND Lot.Status <> 'HOLD'                                       
                              ORDER BY ID DESC

                              IF @@ROWCOUNT = 0
                              BEGIN
                                 IF @b_debug = 2
                                 BEGIN
                                    Print 'Stop because No Pallet Found! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_FromLOC
                                    + ' From ID = ' + @c_fromid
                                 END
                                 SET ROWCOUNT 0
                                 BREAK
                              END
                              SET ROWCOUNT 0
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
                              AND STATUS = 'HOLD')
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
                              AND LocationType = 'PICK'
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
                              AND LocationType = 'CASE'
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
                                 SELECT @n_FromQty = @n_RemainingQty
                                 SELECT @n_RemainingQty = 0
                              END
                              ELSE
                              BEGIN
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

                              IF @n_FromQty > 0
                              BEGIN
                                 SELECT @c_Packkey = PACK.PackKey,
                                          @c_UOM = PACK.PackUOM3
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
                           SET ROWCOUNT 0
                        END -- SCAN LOT for LOC
                        SET ROWCOUNT 0
                     END -- SCAN LOT FOR LOT
                     DROP TABLE #LOT
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

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
      
      --For debug ONLY
      IF @b_debug = 2
      BEGIN
         SELECT R.*, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05
         FROM #REPLENISHMENT R
         JOIN LOTATTRIBUTE LA (NOLOCK) ON R.LOT = LA.LOT
         
         GOTO QUIT_SP
      END
                  
      IF @n_continue=1 OR @n_continue=2
      BEGIN 
         SET @n_Rowcnt = 0
         SELECT    @n_Rowcnt = Count(1)
         FROM   #REPLENISHMENT R
            
         IF ISNULL(@n_Rowcnt, 0) > 0
         BEGIN
               -- Get Key by BATCH
               
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
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 66010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to get REPLENISHKEY. (isp_ReplenishmentRpt_BatchRefill_21)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 66015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into Replenishment table failed. (isp_ReplenishmentRpt_BatchRefill_21)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END

            Set @n_ReplenishmentKey = @n_ReplenishmentKey + 1

            FETCH NEXT FROM CUR1 INTO @n_ROWREF
         END -- While
         CLOSE CUR1 
         DEALLOCATE CUR1
                 
         COMMIT TRAN
      END   
R_ERROR:
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ReplenishmentRpt_BatchRefill_21'
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
   END                                                               

   IF @c_FuncType = 'G'                                              
   BEGIN  
      GOTO QUIT_SP
   END

   IF ( @c_zone02 = 'ALL')
   BEGIN
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, L2.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, (LT.Qty - LT.QtyAllocated - LT.QtyPicked) As QtyAvailable, LA.Lottable02, LA.Lottable04
      FROM  REPLENISHMENT R, SKU (NOLOCK), LOC L1 (NOLOCK), PACK (NOLOCK),  LOC L2 (nolock), LOTxLOCxID LT (nolock) , LOTATTRIBUTE LA (NOLOCK)-- Pack table added by Jacob Date Jan 03, 2001
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
      AND  SKU.PackKey = PACK.PackKey
      AND  R.confirmed = 'N'
      AND  L1.Facility = @c_zone01
      AND  (LT.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')      
      AND  LA.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_zone08),'') = '' THEN LA.Lottable01 ELSE @c_zone08 END     
      AND  LA.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_zone09),'') = '' THEN LA.Lottable02 ELSE @c_zone09 END 
      AND  LA.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_zone10),'') = '' THEN LA.Lottable03 ELSE @c_zone10 END  
      AND  LA.Lottable04 = CASE WHEN ISNULL(RTRIM(@c_zone11),'') = '' THEN LA.Lottable04 ELSE @c_zone11 END  
      AND  LA.Lottable05 = CASE WHEN ISNULL(RTRIM(@c_zone12),'') = '' THEN LA.Lottable05 ELSE @c_zone12 END        
      --AND  LT.SKU BETWEEN @c_zone09 AND @c_zone10 
      --AND  L1.LocAisle BETWEEN @c_zone11 AND @c_zone12 
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  
      ORDER BY L1.PutawayZone, R.FromLoc, R.SKU 
   END
   ELSE
   BEGIN
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, L2.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, (LT.Qty - LT.QtyAllocated - LT.QtyPicked) As QtyAvailable, LA.Lottable02, LA.Lottable04
      FROM  REPLENISHMENT R, SKU (NOLOCK), LOC L1 (NOLOCK), LOC L2 (nolock) , PACK (NOLOCK) , LOTxLOCxID LT(nolock), LOTATTRIBUTE LA (NOLOCK) -- Pack table added by Jacob Date Jan 03, 2001
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
      AND   SKU.PackKey = PACK.PackKey
      AND   R.confirmed = 'N'
      AND   L1.Facility = @c_zone01
      AND   L1.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07)
      AND   (LT.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')
      AND   LA.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_zone08),'') = '' THEN LA.Lottable01 ELSE @c_zone08 END     
      AND   LA.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_zone09),'') = '' THEN LA.Lottable02 ELSE @c_zone09 END 
      AND   LA.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_zone10),'') = '' THEN LA.Lottable03 ELSE @c_zone10 END  
      AND   LA.Lottable04 = CASE WHEN ISNULL(RTRIM(@c_zone11),'') = '' THEN LA.Lottable04 ELSE @c_zone11 END  
      AND   LA.Lottable05 = CASE WHEN ISNULL(RTRIM(@c_zone12),'') = '' THEN LA.Lottable05 ELSE @c_zone12 END            
      --AND   LT.SKU BETWEEN @c_zone09 AND @c_zone10 
      --AND   L1.LocAisle BETWEEN @c_zone11 AND @c_zone12 
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  
      ORDER BY L1.PutawayZone, R.FromLoc, R.SKU 
   END
   QUIT_SP:                                                          
END

GO