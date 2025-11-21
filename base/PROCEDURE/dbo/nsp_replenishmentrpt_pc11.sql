SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: nsp_ReplenishmentRpt_PC11                                   */
/* Creation Date: 27-Nov-2008                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Wave Replenishment Report                                   */
/*                                                                      */
/* Called By: Replenishment entry's RCM                                 */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* UPDATEs:                                                             */
/* Date         Author    Ver.   Purposes                               */
/* 27-Nov-2008  KC        1.0    SOS#120783 - Replen by full pallet only*/
/*                               Changed from nsp_replenishmentRpt_PC06 */
/*                               -- (KC01)                              */
/* 05-MAR-2018  Wan01     1.1   WM - Add Functype                       */
/* 05-OCT-2018  CZTENG01  1.2   WM - Add ReplGrp                        */
/************************************************************************/

CREATE PROC  [dbo].[nsp_ReplenishmentRpt_PC11]
  @c_zone01           NVARCHAR(10) 
 ,@c_zone02           NVARCHAR(10) 
 ,@c_zone03           NVARCHAR(10) 
 ,@c_zone04           NVARCHAR(10) 
 ,@c_zone05           NVARCHAR(10) 
 ,@c_zone06           NVARCHAR(10) 
 ,@c_zone07           NVARCHAR(10) 
 ,@c_zone08           NVARCHAR(10) 
 ,@c_zone09           NVARCHAR(10) 
 ,@c_zone10           NVARCHAR(10) 
 ,@c_zone11           NVARCHAR(10) 
 ,@c_zone12           NVARCHAR(10)
 ,@c_storerkey        NVARCHAR(15)
 ,@c_ReplGrp          NVARCHAR(30) = 'ALL' --(CZTENG01)
 ,@c_Functype         NCHAR(1) = ''        --(Wan01)  
 AS
 BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        
   DECLARE        @n_continue int          /* continuation flag 
      1=Continue
      2=failed but continue processsing 
      3=failed do not continue processing 
      4=successful but skip furthur processing */
   DECLARE @b_debug int,
            @c_Packkey NVARCHAR(10),
            @c_UOM     NVARCHAR(10) -- SOS 8935 wally 13.dec.2002 FROM NVARCHAR(5) to NVARCHAR(10)
   SELECT @n_continue=1, @b_debug = 0
   
-- DECLARE @n_qty int   -- SOS33782 - June 30.Mar.2005
   
   --(Wan01) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
   
   IF @c_FuncType IN ( 'P' )                                         
   BEGIN          
      GOTO QUIT_SP                                                      
   END
   --(Wan01) - END

   IF ISNULL(@c_zone12,'') <> '' 
      SELECT @b_debug = CAST( @c_zone12 AS int)
   -- create temp LOTXLOCXID
   SELECT lot, rowid=newid(), linenum=0
   INTO #Temp_LOTXLOCXID
   FROM LOTXLOCXID WITH (NOLOCK)
   WHERE 1 = 2

   DECLARE @c_priority  NVARCHAR(5)
   SELECT StorerKey, SKU, LOC FROMLOC, LOC ToLOC, Lot, Id, Qty, Qty QtyMoved, Qty QtyInPickLOC,
      @c_priority Priority, Lot UOM, Lot PackKey
   INTO #REPLENISHMENT
   FROM LOTXLOCXID WITH (NOLOCK)
   WHERE 1 = 2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_CurrentSKU NVARCHAR(20), @c_CurrentStorer NVARCHAR(15),
               @c_CurrentLOC NVARCHAR(10), @c_CurrentPriority NVARCHAR(5),
               @n_CurrentFullcase int, @n_CurrentSeverity int,
               @c_FromLOC NVARCHAR(10), @c_FromLOT NVARCHAR(10), @c_FromID NVARCHAR(18),
               @n_FromQty int, @n_RemainingQty int, @n_PossibleCases int ,
               @n_RemainingCases int, @n_OnHandQty int, @n_FromCases int ,
               @c_ReplenishmentKey NVARCHAR(10), @n_NumberOfRecs int, @n_limitrecs int,
               @c_FromLOT2 NVARCHAR(10),
               @b_DoneCheckOverallocatedLots int,
               @n_SKULOCavailableqty int,
               @n_pallet int, @n_PossiblePallet int
      SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
               @c_CurrentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),
               @n_CurrentFullcase = 0   , @n_CurrentSeverity = 9999999 ,
               @n_FromQty = 0, @n_RemainingQty = 0, @n_PossibleCases = 0, 
               @n_RemainingCases =0, @n_FromCases = 0, @n_NumberOfRecs = 0,                 
               @n_limitrecs = 5,
               @n_pallet = 0, @n_PossiblePallet = 0
      /* Make a temp version of SKUxLOC */
      SELECT ReplenishmentPriority, ReplenishmentSeverity, StorerKey,
         SKU, LOC, ReplenishmentCasecnt
      INTO #TempSKUxLOC
      FROM SKUxLOC WITH (NOLOCK)
      WHERE 1=2

      IF (ISNULL(@c_zone02,'') = 'ALL')
      BEGIN
         INSERT #TempSKUxLOC
            SELECT ReplenishmentPriority, ReplenishmentSeverity, StorerKey,
               SKU, SKUxLOC.LOC, ReplenishmentCasecnt
            FROM SKUxLOC WITH (NOLOCK), LOC WITH (NOLOCK)
            WHERE SKUxLOC.LOC = LOC.LOC
            AND   (SKUxLOC.LocationType = 'PICK' OR SKUxLOC.LocationType = 'CASE')
            AND   LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')   -- SOS38137
            AND   LOC.Status <> 'HOLD' -- SOS38137
            AND   ReplenishmentSeverity > 0
            AND   SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum
            AND  (SKUXLOC.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')  
            AND   LOC.FACILITY = ISNULL(@c_zone01,'')
      END
      ELSE
      BEGIN
         INSERT #TempSKUxLOC
            SELECT ReplenishmentPriority, ReplenishmentSeverity, StorerKey,
               SKU, LOC.LOC, ReplenishmentCasecnt
            FROM SKUxLOC WITH (NOLOCK), LOC WITH (NOLOCK)
            WHERE SKUxLOC.LOC = LOC.LOC
            AND   (SKUxLOC.LocationType = 'PICK' OR SKUxLOC.LocationType = 'CASE')
            AND   LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND   LOC.Status <> 'HOLD' -- SOS38137
            AND   ReplenishmentSeverity > 0
            AND   SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtylocationMinimum
            AND  (SKUXLOC.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')  
            AND   LOC.FACILITY = ISNULL(@c_zone01,'')
            AND   LOC.PutawayZone IN (ISNULL(@c_zone02,''), ISNULL(@c_zone03,''), ISNULL(@c_zone04,''), 
                  ISNULL(@c_zone05,''), ISNULL(@c_zone06,''), ISNULL(@c_zone07,''), ISNULL(@c_zone08,''), 
                  ISNULL(@c_zone09,''), ISNULL(@c_zone10,''), ISNULL(@c_zone11,''), ISNULL(@c_zone12,''))
      END
   
--       -- Start : SOS33782 - June 30.Mar.2005
--       -- create a temporary LOTXLOCXID FOR processing to avoid suggesting same record twice
--       -- FOR sku with multiple pick location
--       SELECT lli.*
--       INTO #LOTXLOCXID
--       FROM LOTXLOCXID lli WITH (NOLOCK) 
--       join #tempskuxloc t WITH (NOLOCK) on lli.storerkey = t.storerkey AND lli.sku = t.sku
--       WHERE lli.qty-QtyAllocated-QtyPicked > 0
--       AND lli.loc <> t.loc
--       -- End : SOS33782 
      
      WHILE (1=1)
      BEGIN
-- Remarked by MaryVong on 03-Aug-2005
--          IF @c_zone02 = 'ALL' 
--          BEGIN
         SET ROWCOUNT 1
         SELECT @c_CurrentPriority = ReplenishmentPriority
         FROM #TempSKUxLOC 
         WHERE ReplenishmentPriority > @c_CurrentPriority
         AND   ReplenishmentCasecnt > 0
         ORDER BY ReplenishmentPriority
--          END
--          ELSE
--          BEGIN
--             SET ROWCOUNT 1
--             SELECT @c_CurrentPriority = ReplenishmentPriority
--             FROM #TempSKUxLOC
--             WHERE ReplenishmentPriority > @c_CurrentPriority
--             AND  ReplenishmentCasecnt > 0
--             ORDER BY ReplenishmentPriority
--          END
   
         IF @@ROWCOUNT = 0
         BEGIN
            SET ROWCOUNT 0
            BREAK
         END
         SET ROWCOUNT 0
   
         /* Loop through SKUxLOC FOR the currentSKU, current storer */
         /* to pickup the next severity */
         SELECT @n_CurrentSeverity = 999999999               
         WHILE (1=1)
         BEGIN
            SET ROWCOUNT 1
            SELECT @n_CurrentSeverity = ReplenishmentSeverity
            FROM #TempSKUxLOC
            WHERE ReplenishmentSeverity < @n_CurrentSeverity
            AND   ReplenishmentPriority = @c_CurrentPriority
            AND   ReplenishmentCasecnt > 0
            ORDER BY ReplenishmentSeverity DESC
            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0
   
            /* Now - FOR this priority, this severity - find the next storer row */
            /* that matches */
            SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15), @c_CurrentLOC = SPACE(10)
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1
               SELECT @c_CurrentStorer = StorerKey
               FROM #TempSKUxLOC
               WHERE StorerKey > ISNULL(@c_CurrentStorer,'')
               AND   ReplenishmentSeverity = @n_CurrentSeverity
               AND   ReplenishmentPriority = @c_CurrentPriority
               ORDER BY StorerKey
   
               IF @@ROWCOUNT = 0
               BEGIN
                  SET ROWCOUNT 0
                  BREAK
               END
               SET ROWCOUNT 0
   
               /* Now - FOR this priority, this severity - find the next SKU row */
               /* that matches */
               SELECT @c_CurrentSKU = SPACE(20),
                  @c_CurrentLOC = SPACE(10)
               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_CurrentStorer = StorerKey ,
                     @c_CurrentSKU = SKU,
                     @c_CurrentLOC = LOC,
                     @n_CurrentFullcase = ReplenishmentCasecnt
                  FROM #TempSKUxLOC
                  -- Start : SOS33782 - June > to hANDle multiple pick loc FOR 1 sku
                  WHERE SKU + LOC > @c_CurrentSKU + @c_CurrentLOC
                  -- WHERE SKU > @c_CurrentSKU
                  -- End : SOS33782
                  AND   StorerKey = ISNULL(@c_CurrentStorer,'')
                  AND   ReplenishmentSeverity = ISNULL(@n_CurrentSeverity,'')
                  AND   ReplenishmentPriority = ISNULL(@c_CurrentPriority,'')
                  ORDER BY SKU
   
                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET ROWCOUNT 0
                     BREAK
                  END

                  SET ROWCOUNT 0

IF @b_debug = 1 
BEGIN
   SELECT @c_CurrentStorer '@c_CurrentStorer', @c_CurrentSKU '@c_CurrentSKU', @c_CurrentLOC '@c_CurrentLOC'
END   
                  -- to include shelflife of an item
                  -- FOR Unilever Philippines
                  -- by Wally 05.sep.2001
                  DECLARE @n_ShelfLife int
   
                  SELECT @n_ShelfLife = ISNULL(ShelfLife, 0)
                  FROM SKU WITH (NOLOCK)
                  WHERE Sku = @c_CurrentSKU
                  AND   StorerKey = @c_CurrentStorer
   
                  /* We now have a picklocation that needs to be replenished! */
                  /* Figure out which locations in the warehouse to pull this product from */
                  /* End figure out which locations in the warehouse to pull this product from */                              
                  
                  SELECT @c_FromLOC = SPACE(10),  @c_FromLOT = SPACE(10), @c_FromID = SPACE(18), 
                  @n_FromQty = 0, @n_PossibleCases = 0,
                  @n_RemainingQty = @n_CurrentSeverity * @n_CurrentFullcase,
                  @n_RemainingCases = @n_CurrentSeverity,
                  @c_FromLOT2 = SPACE(10),
                  @b_DoneCheckOverallocatedLots = 0                                     
   
                  /* Create a temp LOTXLOCXID */
                  TRUNCATE TABLE #Temp_LOTXLOCXID

                  IF ISNULL(@c_zone02,'') = 'ALL'
                  BEGIN                   
                     INSERT #Temp_LOTXLOCXID
                     SELECT LOTXLOCXID.LOT, rowid=newid(), linenum=0
                     FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK),
                          LOT WITH (NOLOCK) -- SOS38137 Added LOT
                     WHERE LOTXLOCXID.StorerKey = ISNULL(@c_CurrentStorer,'')
                     AND   LOTXLOCXID.SKU = ISNULL(@c_CurrentSKU,'')
                     AND   LOTXLOCXID.LOC = LOC.LOC
                     AND   LOC.LocationFlag <> 'DAMAGE'
                     AND   LOC.LocationFlag <> 'HOLD'
                     AND   LOC.Status <> 'HOLD' -- SOS38137
                     AND   LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated > 0
                     AND   LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND 
                     AND   LOTXLOCXID.LOC <> ISNULL(@c_CurrentLOC,'')
                     AND   LOTATTRIBUTE.LOT = LOTXLOCXID.LOT
                     -- SOS38137 -Start
                     AND   LOTXLOCXID.LOT = LOT.LOT
                     AND   LOT.Status = 'OK'
                     -- End
                     AND   (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR
                           LOTATTRIBUTE.Lottable03 = 'ULP-01' OR
                           LOTATTRIBUTE.Lottable03 = '')
                     -- SOS38137
                     AND   LOC.FACILITY = ISNULL(@c_zone01,'')
                     GROUP BY LOTXLOCXID.LOT, Lottable04, Lottable05 -- SOS33782
                     ORDER BY DATEADD(DAY, @n_ShelfLife, Lottable04), Lottable05
                  END
                  ELSE
                  BEGIN
                     INSERT #Temp_LOTXLOCXID
                     SELECT LOTXLOCXID.LOT, rowid=newid(), linenum=0
                     FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK),
                          LOT WITH (NOLOCK) -- SOS38137 Added LOT
                     WHERE LOTXLOCXID.StorerKey = ISNULL(@c_CurrentStorer,'')
                     AND   LOTXLOCXID.SKU = ISNULL(@c_CurrentSKU,'')
                     AND   LOTXLOCXID.LOC = LOC.LOC
                     AND   LOC.LocationFlag <> 'DAMAGE'
                     AND   LOC.LocationFlag <> 'HOLD'
                     AND   LOC.Status <> 'HOLD' -- SOS38137
                     AND   LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated > 0
                     AND   LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND 
                     AND   LOTXLOCXID.LOC <> @c_CurrentLOC
                     AND   LOTATTRIBUTE.LOT = LOTXLOCXID.LOT
                     -- SOS38137 -Start
                     AND   LOTXLOCXID.LOT = LOT.LOT
                     AND   LOT.Status = 'OK'
                     -- End
                     AND   (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR
                           LOTATTRIBUTE.Lottable03 = 'ULP-01' OR
                           LOTATTRIBUTE.Lottable03 = '')
                     -- SOS38137
                     AND   LOC.FACILITY = ISNULL(@c_zone01,'')
                     AND   LOC.PutawayZone IN (ISNULL(@c_zone02,''), ISNULL(@c_zone03,''), ISNULL(@c_zone04,''), 
                           ISNULL(@c_zone05,''), ISNULL(@c_zone06,''), ISNULL(@c_zone07,''), 
                           ISNULL(@c_zone08,''), ISNULL(@c_zone09,''), ISNULL(@c_zone10,''), ISNULL(@c_zone11,''), ISNULL(@c_zone12,''))                    
                     GROUP BY LOTXLOCXID.LOT, Lottable04, Lottable05 -- SOS33782
                     ORDER BY DATEADD(DAY, @n_ShelfLife, Lottable04), Lottable05
                  END
   
                  DECLARE @c_lot NVARCHAR(10),
                           @u_rowid uniqueidentifier,
                           @n_linenum int
   
                  SELECT @n_linenum = 0
                  -- assign unique rowid
                  DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY 
                  FOR
                  SELECT lot, rowid FROM #Temp_LOTXLOCXID
   
                  OPEN cur_1
                  FETCH NEXT FROM cur_1 INTO @c_lot, @u_rowid
                  WHILE (@@fetch_status <> -1)
                  BEGIN
                     UPDATE #Temp_LOTXLOCXID
                     SET linenum = @n_linenum + 1
                     WHERE rowid = @u_rowid
   
                     SELECT @n_linenum = @n_linenum + 1
                     FETCH NEXT FROM cur_1 INTO @c_lot, @u_rowid
                  END
                  CLOSE cur_1
                  DEALLOCATE cur_1

                  WHILE (1=1)
                  BEGIN
                     /* See if there are any lots where the qty is overallocated... */
                     /* if Yes then uses this lot first... */
                     -- That means that the last try at this section of code was successful therefore try again.
                     IF @b_DoneCheckOverallocatedLots = 0 
                     BEGIN
                        IF ISNULL(@c_zone02,'') = 'ALL'
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_FromLOT2 = LOTXLOCXID.LOT 
                           FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK),
                                LOT WITH (NOLOCK) -- SOS38137 Added LOT                      
                           WHERE LOTXLOCXID.LOT > ISNULL(@c_FromLOT2,'')
                           AND   LOTXLOCXID.StorerKey = ISNULL(@c_CurrentStorer,'')
                           AND   LOTXLOCXID.SKU = ISNULL(@c_CurrentSKU,'')
                           AND   LOTXLOCXID.LOC = LOC.LOC
                           AND   LOC.LocationFlag <> 'DAMAGE'
                           AND   LOC.LocationFlag <> 'HOLD'
                           AND   LOC.Status <> 'HOLD' -- SOS38137
                           AND   LOTXLOCXID.QtyExpected > 0
                           AND   LOTXLOCXID.LOC = ISNULL(@c_CurrentLOC,'')
                           AND   LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
                           -- SOS38137 -Start
                           AND   LOTXLOCXID.LOT = LOT.LOT
                           AND   LOT.Status = 'OK'
                           -- End
                           AND   (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR
                                 LOTATTRIBUTE.Lottable03 = 'ULP-01' OR
                                 LOTATTRIBUTE.Lottable03 = '')
                           AND   LOC.FACILITY = ISNULL(@c_Zone01,'')
                           ORDER BY DATEADD(DAY, @n_ShelfLife, Lottable04), Lottable05
                        END
                        ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_FromLOT2 = LOTXLOCXID.LOT 
                           FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK),
                                LOT WITH (NOLOCK) -- SOS38137 Added LOT                      
                           WHERE LOTXLOCXID.LOT > ISNULL(@c_FromLOT2,'')
                           AND   LOTXLOCXID.StorerKey = ISNULL(@c_CurrentStorer,'')
                           AND   LOTXLOCXID.SKU = ISNULL(@c_CurrentSKU,'')
                           AND   LOTXLOCXID.LOC = LOC.LOC
                           -- SOS38137 -Start
                           AND   LOC.LocationFlag <> 'DAMAGE'
                           AND   LOC.LocationFlag <> 'HOLD'
                           AND   LOC.Status <> 'HOLD'
                           -- End
                           AND   LOTXLOCXID.QtyExpected > 0
                           AND   LOTXLOCXID.LOC = ISNULL(@c_CurrentLOC,'')
                           AND   LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
                           -- SOS38137 -Start
                           AND   LOTXLOCXID.LOT = LOT.LOT
                           AND   LOT.Status = 'OK'
                           -- End
                           AND   (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR
                                 LOTATTRIBUTE.Lottable03 = 'ULP-01' OR
                                 LOTATTRIBUTE.Lottable03 = '')
                           -- SOS38137
                           AND   LOC.FACILITY = ISNULL(@c_Zone01,'')
                           AND   LOC.PutawayZone IN (ISNULL(@c_zone02,''), ISNULL(@c_zone03,''), ISNULL(@c_zone04,''), 
                           ISNULL(@c_zone05,''), ISNULL(@c_zone06,''), ISNULL(@c_zone07,''), 
                           ISNULL(@c_zone08,''), ISNULL(@c_zone09,''), ISNULL(@c_zone10,''), ISNULL(@c_zone11,''), ISNULL(@c_zone12,''))           
                           ORDER BY DATEADD(DAY, @n_ShelfLife, Lottable04), Lottable05
                        END     
                        IF @@ROWCOUNT = 0
                        BEGIN
                           SELECT @b_DoneCheckOverallocatedLots = 1
                           SELECT @c_FromLOT = ''
                           SELECT @n_linenum = 0
                        END         
                        ELSE
                        BEGIN                                
                           SELECT @b_DoneCheckOverallocatedLots = 1
                           -- SOS38137
                           SELECT @c_FromLOT = ''
                           SELECT @n_linenum = 0 
                        END                              
                     END --IF @b_DoneCheckOverallocatedLots = 0
            
                     /* End see if there are any lots where the qty is overallocated... */
                     SET ROWCOUNT 0
                     /* If there are not lots overallocated in the candidate location, simply pull lots into the location by lot # */
                     IF @b_DoneCheckOverallocatedLots = 1
                     BEGIN                      
                        /* SELECT any lot if no lot was over alLOCated */      
                        IF ISNULL(@c_zone02,'') = 'ALL'
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_FromLOT = lot, @n_linenum = linenum
                           FROM #Temp_LOTXLOCXID
                           WHERE linenum > @n_linenum
                           ORDER BY linenum
 --                           SELECT @c_FromLOT = LOTXLOCXID.LOT 
 --                           FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK)
 --                           WHERE LOTXLOCXID.LOT > ISNULL(@c_FromLOT,'')
 --                              AND LOTXLOCXID.StorerKey = ISNULL(@c_CurrentStorer,'')
 --                              AND LOTXLOCXID.SKU = ISNULL(@c_CurrentSKU,'')
 --                              AND LOTXLOCXID.LOC = LOC.LOC
 --                              AND LOC.LocationFlag <> 'DAMAGE'
 --                              AND LOC.LocationFlag <> 'HOLD'
 --                              AND LOTXLOCXID.qty - QtyPicked - QtyAllocated > 0
 --                              AND LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND 
 --                              AND LOTXLOCXID.LOC <> ISNULL(@c_CurrentLOC,'')
 --                              AND LOTATTRIBUTE.LOT = LOTXLOCXID.LOT
 --                              AND (LOTATTRIBUTE.Lottable03 = 'BIC-01' or
 --                                     lotattribute.lottable03 = 'ULP-01' or
 --                                     lotattribute.lottable03 = '')
 --                           ORDER BY DATEADD(day, @n_ShelfLife, LOTTABLE04), LOTTABLE05
                        END
                        ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_FromLOT = lot, @n_linenum = linenum
                           FROM #Temp_LOTXLOCXID
                           WHERE linenum > @n_linenum
                           ORDER BY linenum
 --                           SELECT @c_FromLOT = LOTXLOCXID.LOT 
 --                           FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK)
 --                           WHERE LOTXLOCXID.LOT > ISNULL(@c_FromLOT,'')
 --                              AND LOTXLOCXID.StorerKey = ISNULL(@c_CurrentStorer,'')
 --                              AND LOTXLOCXID.SKU = ISNULL(@c_CurrentSKU,'')
 --                              AND LOTXLOCXID.LOC = LOC.LOC
 --                              AND LOC.LocationFlag <> 'DAMAGE'
 --                              AND LOC.LocationFlag <> 'HOLD'
 --                              AND LOTXLOCXID.qty - QtyPicked - QtyAllocated > 0
--                               AND LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND 
 --                              AND LOTXLOCXID.LOC <> ISNULL(@c_CurrentLOC,'')
 --                              AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
 --                              AND (LOTATTRIBUTE.Lottable03 = 'BIC-01' or
 --                                     lotattribute.lottable03 = 'ULP-01' or
 --                                     lotattribute.lottable03 = '')
 --                           ORDER BY DATEADD(day, @n_ShelfLife, LOTTABLE04), LOTTABLE05
                        END     
                        IF @@ROWCOUNT = 0
                        BEGIN
                           IF @b_debug = 1
                           SELECT 'No Lot Available! SKU= ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentSKU)),'') + ' LOC=' + 
                              ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentLOC)),''), 'LOT=' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromLOT)),'')
                           SET ROWCOUNT 0
                           BREAK
                        END
                        SET ROWCOUNT 0
                     END
                     ELSE
                     BEGIN
                        SELECT @c_FromLOT = ISNULL(@c_FromLOT2,'')
                     END -- IF @b_DoneCheckOverallocatedLots = 1

                     SET ROWCOUNT 0
                     SELECT @c_FromLOC = SPACE(10)
                     WHILE (1=1 AND @n_RemainingQty > 0)
                     BEGIN
                        IF ISNULL(@c_zone02,'') = 'ALL'
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_FromLOC = LOTXLOCXID.LOC
                           FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK)
                           WHERE LOT = ISNULL(@c_FromLOT,'')
                           AND   LOTXLOCXID.LOC = LOC.LOC                                             
                           AND   LOTXLOCXID.LOC > ISNULL(@c_FromLOC,'')
                           AND   StorerKey = ISNULL(@c_CurrentStorer,'')
                           AND   SKU = ISNULL(@c_CurrentSKU,'')
                           AND   LOTXLOCXID.LOC = LOC.LOC
                           AND   LOC.LocationFlag <> 'DAMAGE'
                           AND   LOC.LocationFlag <> 'HOLD'
                           AND   LOC.Status <> 'HOLD' -- SOS38137
                           AND   LOTXLOCXID.qty - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated > 0
                           AND   LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND 
                           AND   LOTXLOCXID.LOC <> ISNULL(@c_CurrentLOC,'')
                           AND   LOC.Facility = ISNULL(@c_zone01,'') -- By June - SOS13417, to avoid replen FROM other Facility
                           ORDER BY LOTXLOCXID.LOC
                        END
                        ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_FromLOC = LOTXLOCXID.LOC
                           FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK)
                           WHERE LOT = ISNULL(@c_FromLOT,'')
                           AND   LOTXLOCXID.LOC = LOC.LOC                                             
                           AND   LOTXLOCXID.LOC > ISNULL(@c_FromLOC,'')
                           AND   StorerKey = ISNULL(@c_CurrentStorer,'')
                           AND   SKU = ISNULL(@c_CurrentSKU,'')
                           AND   LOTXLOCXID.LOC = LOC.LOC
                           AND   LOC.LocationFlag <> 'DAMAGE'
                           AND   LOC.LocationFlag <> 'HOLD'
                           AND   LOC.Status <> 'HOLD' -- SOS38137
                           AND   LOTXLOCXID.qty - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated > 0
                           AND   LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND 
                           AND   LOTXLOCXID.LOC <> ISNULL(@c_CurrentLOC,'')
                           AND   LOC.Facility = ISNULL(@c_zone01,'') -- By June - SOS13417, to avoid replen from other Facility
                           ORDER BY LOTXLOCXID.LOC
                        END
                        IF @@ROWCOUNT = 0
                        BEGIN
                           SET ROWCOUNT 0
                           BREAK
                        END
IF @b_debug = 1 
BEGIN
   SELECT @c_FromLOC '@c_FromLOC'
END
                        SET ROWCOUNT 0
                        SELECT @c_FromID = replicate('Z',18)
                        WHILE (1=1 AND @n_RemainingQty > 0)
                        BEGIN
                           IF ISNULL(@c_zone02,'') = 'ALL'
                           BEGIN
                              SET ROWCOUNT 1
                              SELECT @c_FromID = ID,
                              @n_OnHandQty = LOTXLOCXID.QTY - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated
                              FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK)
                              WHERE LOT = ISNULL(@c_FromLOT,'')
                              AND   LOTXLOCXID.LOC = LOC.LOC
                              AND   LOTXLOCXID.LOC = ISNULL(@c_FromLOC,'')
                              AND   Id < ISNULL(@c_FromID,'')
                              AND   StorerKey = ISNULL(@c_CurrentStorer,'')
                              AND   SKU = ISNULL(@c_CurrentSKU,'')
                              AND   LOC.LocationFlag <> 'DAMAGE'
                              AND   LOC.LocationFlag <> 'HOLD'
                              AND   LOC.Status <> 'HOLD' -- SOS38137
                              AND   LOTXLOCXID.qty - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated > 0
                              AND   LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND 
                              AND   LOTXLOCXID.LOC <> ISNULL(@c_CurrentLOC,'')
                              ORDER BY ID DESC
                           END
                           ELSE
                           BEGIN
                              SET ROWCOUNT 1
                              SELECT @c_FromID = ID,
                              @n_OnHandQty = LOTXLOCXID.QTY - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated
                              FROM LOTXLOCXID WITH (NOLOCK), LOC WITH (NOLOCK)
                              WHERE LOT = ISNULL(@c_FromLOT,'')
                              AND   LOTXLOCXID.LOC = LOC.LOC
                              AND   LOTXLOCXID.LOC = ISNULL(@c_FromLOC,'')
                              AND   Id < ISNULL(@c_FromID,'')
                              AND   StorerKey = ISNULL(@c_CurrentStorer,'')
                              AND   SKU = ISNULL(@c_CurrentSKU,'')
                              AND   LOC.LocationFlag <> 'DAMAGE'
                              AND   LOC.LocationFlag <> 'HOLD'
                              AND   LOC.Status <> 'HOLD' -- SOS38137
                              AND   LOTXLOCXID.qty - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated > 0
                              AND   LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND 
                              AND   LOTXLOCXID.LOC <> ISNULL(@c_CurrentLOC,'')
                              ORDER BY ID DESC 
                           END
                           IF @@ROWCOUNT = 0
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because No Pallet Found! LOC = ' + ISNULl(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentLOC)),'') + 
                                    ' SKU = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentSKU)),'') + 
                                    ' LOT = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromLOT)),'') + 
                                    ' FROM LOC = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromLOC)),'') +
                                    ' FROM ID = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromID)),'')
                              END
                              SET ROWCOUNT 0
                              BREAK 
                           END   
                           SET ROWCOUNT 0
                           /* We have a candidate from record */
                           /* Verify that the candidate ID is not on HOLD */
                           /* We could have done this in the SQL statements above */
                           /* But that would have meant a 5-way join.             */
                           /* SQL SERVER seems to work best on a maximum of a     */
                           /* 4-way join.                                         */
                           IF EXISTS(SELECT * FROM ID WITH (NOLOCK) WHERE ID = ISNULL(@c_FromID,'') AND STATUS = 'HOLD')
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because ID Status = HOLD! LOC = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentLOC)),'') + 
                                    ' SKU = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentSKU)),'') + 
                                    ' ID = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromID)),'')
                              END
                              BREAK -- Get out of loop, so that next candidate can be evaluated
                           END     
IF @b_debug = 1 
BEGIN
   SELECT @c_FromID '@c_FromID'
END                                                                                                 
                           /* Verify that the from location is not overallocated in SKUxLOC */
                           IF EXISTS(SELECT * FROM SKUxLOC WITH (NOLOCK)
                           WHERE StorerKey = ISNULL(@c_CurrentStorer,'')
                           AND   SKU = ISNULL(@c_CurrentSKU,'')
                           AND   LOC = ISNULL(@c_FromLOC,'')
                           AND   QtyExpected > 0)
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because Qty Expected > 0! LOC = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentLOC)),'') + 
                                    ' SKU = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentSKU)),'')
                              END
                              BREAK -- Get out of loop, so that next candidate can be evaluated
                           END
                           /* Verify that the from location is not the */
                           /* PIECE PICK location FOR this product.    */
                           IF EXISTS(SELECT * FROM SKUxLOC WITH (NOLOCK)
                                    WHERE StorerKey = ISNULL(@c_CurrentStorer,'')
                                    AND   SKU = ISNULL(@c_CurrentSKU,'')
                                    AND   LOC = ISNULL(@c_FromLOC,'')
                                    AND   LocationType = 'PICK')
                           BEGIN 
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because location Type = PICK! LOC = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentLOC)),'') + 
                                    ' SKU = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentSKU)),'')
                              END
                              BREAK -- Get out of loop, so that next candidate can be evaluated                                                  
                           END
                           /* Verify that the from location is not the */
                           /* CASE PICK location FOR this product.     */
                           IF EXISTS(SELECT * FROM SKUxLOC WITH (NOLOCK)
                                    WHERE StorerKey = ISNULL(@c_CurrentStorer,'')
                                    AND   SKU = ISNULL(@c_CurrentSKU,'')
                                    AND   LOC = ISNULL(@c_FromLOC,'')
                                    AND   LocationType = 'CASE')
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because location Type = CASE! LOC = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentLOC)),'') + 
                                    ' SKU = ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_CurrentSKU)),'')
                              END
                              BREAK -- Get out of loop, so that next candidate can be evaluated                                                  
                           END
                           /* At this point, get the available qty from */
                           /* the SKUxLOC record.                       */
                           /* If it's less than what was taken from the */
                           /* LOTXLOCXID record, then use it.           */
                           SELECT @n_SKULOCavailableqty = QTY - QtyAllocated - QtyPicked
                           FROM SKUxLOC WITH (NOLOCK)
                           WHERE StorerKey = ISNULL(@c_CurrentStorer,'')
                           AND   SKU = ISNULL(@c_CurrentSKU,'')
                           AND   LOC = ISNULL(@c_FromLOC,'')
                           IF ISNULL(@n_SKULOCavailableqty,0) < ISNULL(@n_OnHandQty,0)
                           BEGIN
                              SELECT @n_OnHandQty = ISNULL(@n_SKULOCavailableqty,0)
                           END
                           /* How many cases can I get from this record? */
                           SELECT @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullcase)

                           /* SOS#120783 KC Moved select up here & add pallet */
                           SELECT @c_Packkey = PACK.PackKey,
                                  @c_UOM = PACK.PackUOM3,
                                  @n_pallet = PACK.pallet 
                              FROM SKU WITH (NOLOCK), PACK WITH (NOLOCK)
                              WHERE SKU.PackKey = PACK.Packkey
                              AND   SKU.StorerKey = ISNULL(@c_CurrentStorer,'')
                              AND   SKU.SKU = ISNULL(@c_CurrentSKU,'')
      
                           /* How many do we take? */
                           /* SOS#120783 (KC01) - START */
                           IF @n_pallet = 0 
                              SELECT @n_Pallet = 1


                           IF (@n_OnHandQty > @n_RemainingQty) and (@n_RemainingQty >= @n_pallet)
                           BEGIN
                              SELECT @n_PossiblePallet = floor(@n_RemainingQty / @n_pallet)
                              SELECT @n_FromQty = @n_PossiblePallet * @n_pallet,
                              @n_RemainingQty = 0
                           END
                           ELSE IF (@n_OnHandQty > @n_RemainingQty) and (@n_RemainingQty < @n_pallet)
                           BEGIN
                              SELECT @n_FromQty = @n_RemainingQty,
                              -- @n_RemainingQty = @n_RemainingQty - (@n_RemainingCases * @n_CurrentFullcase),
                              @n_RemainingQty = 0
                           END
                           ELSE IF (@n_OnHandQty <= @n_RemainingQty) and (@n_OnHandQty >= @n_pallet)
                           BEGIN
                              SELECT @n_PossiblePallet = floor(@n_OnHandQty / @n_pallet)
                              SELECT @n_FromQty = @n_PossiblePallet * @n_pallet,
                                 @n_RemainingQty = @n_RemainingQty - @n_OnHandQty
                                 -- @n_RemainingCases =  @n_RemainingCases - @n_PossibleCases
                           END
                           ELSE
                           BEGIN
                              SELECT @n_FromQty = @n_OnHandQty,
                              @n_RemainingQty = @n_RemainingQty - @n_OnHandQty
                           END
                           /* SOS#120783 (KC01) - END */

                           IF @n_FromQty > 0
                           BEGIN
                              
                              IF @n_continue = 1 OR @n_continue = 2
                              BEGIN
                                 INSERT #REPLENISHMENT (
                                       StorerKey, 
                                       SKU,
                                       FROMLOC, 
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
                                       @c_FromLOT,
                                       @c_FromID,
                                       @n_FromQty,
                                       @c_UOM,
                                       @c_Packkey,
                                       @c_CurrentPriority,
                                       0,0)                    
                              END
                              SELECT @n_NumberOfRecs = @n_NumberOfRecs + 1
                              
--                               -- Start : SOS33782 - June 30.Mar.2005
--                               -- create a temporary LOTXLOCXID FOR processing to avoid suggesting same record twice
--                               -- FOR sku with multiple pick location
--                               -- clean up #LOTXLOCXID of those used records
--                               SELECT @n_qty = qty
--                               FROM #LOTXLOCXID
--                               WHERE lot = ISNULL(@c_FromLOT,'')
--                                  AND loc = ISNULL(@c_FromLOC,'')
--                                  AND id = ISNULL(@c_FromID,'')
--                                 AND storerkey = ISNULL(@c_CurrentStorer,'')
--                                  AND sku = ISNULL(@c_CurrentSKU,'')
--                               if @n_FromQty > @n_qty
--                                  UPDATE #LOTXLOCXID
--                                  SET qty = (@n_FromQty - @n_qty)    
--                                  WHERE lot = ISNULL(@c_FromLOT,'')
--                                     AND loc = ISNULL(@c_FromLOC,'')
--                                     AND id = ISNULL(@c_FromID,'')
--                                     AND storerkey = ISNULL(@c_CurrentStorer,'')
--                                     AND sku = ISNULL(@c_CurrentSKU,'')
--                               else
--                                  delete #LOTXLOCXID
--                                  WHERE lot = ISNULL(@c_FromLOT,'')
--                                     AND loc = ISNULL(@c_FromLOC,'')
--                                     AND id = ISNULL(@c_FromID,'')
--                                     AND storerkey = ISNULL(@c_CurrentStorer,'')
--                                     AND sku = ISNULL(@c_CurrentSKU,'')
--                               -- End : SOS33782
                           END -- if FROM qty > 0
                           IF @b_debug = 1 
                           BEGIN
                              SELECT '--- insert Replenishment ---'
                              SELECT @c_CurrentSKU ' SKU', @c_CurrentLOC 'LOC', @c_CurrentPriority 'priority', @n_CurrentFullcase 'full case', @n_CurrentSeverity 'severity'
                                 -- SELECT @n_FromQty 'qty', @c_FromLOC 'FROMLOC', @c_FromLOT 'FROM lot', @n_PossibleCases 'possible cases'
                              SELECT @n_RemainingQty '@n_RemainingQty', @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU, @c_FromLOT 'FROM lot', @c_FromID
                           END
                           IF ISNULL(@c_FromID,'') = '' OR ISNULL(@c_FromID,'') = '' OR ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromID)),'') = ''
                           BEGIN
                              -- SELECT @n_RemainingQty=0   
                              BREAK
                           END
                        END -- SCAN LOT FOR ID
                        SET ROWCOUNT 0
                     END -- SCAN LOT FOR LOC                                   
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
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      /* Update the column QtyInPickLOC in the Replenishment Table */
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         UPDATE #REPLENISHMENT SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked
         FROM SKUxLOC WITH (NOLOCK)
         WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey AND
         #REPLENISHMENT.SKU = SKUxLOC.SKU AND
         #REPLENISHMENT.toLOC = SKUxLOC.LOC 
      END
   END
   /* Insert into Replenishment Table Now */
   DECLARE @b_success int,
   @n_err     int,
   @c_errmsg  NVARCHAR(255)
   
   DECLARE CUR1 CURSOR  FAST_FORWARD READ_ONLY FOR 
   SELECT R.FROMLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM
   FROM #REPLENISHMENT R
      
   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLOC, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLOT, @c_PackKey, @c_Priority, @c_UOM
   
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
               FROMLoc,
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
               @c_FromLOT,
               @c_FromID,
               @n_FromQty,
               @c_UOM,
               @c_PackKey,
               'N')
   
         SELECT @n_err = @@ERROR
      END -- IF @b_success = 1
      FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLOC, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLOT, @c_PackKey, @c_Priority, @c_UOM
   END -- WHILE
   DEALLOCATE CUR1
 -- End Insert Replenishment

   --(Wan01) - START
QUIT_SP:
   IF @c_FuncType IN ( 'G' )                                    
   BEGIN                                                                
      RETURN
   END
   --(Wan01) - END

   IF ( ISNULL(@c_zone02,'') = 'ALL')
   BEGIN             
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, 
         SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey
      FROM REPLENISHMENT R, SKU WITH (NOLOCK), LOC WITH (NOLOCK), PACK WITH (NOLOCK) -- Pack table added by Jacob Date Jan 03, 2001
      WHERE SKU.Sku = R.Sku 
      AND   SKU.StorerKey = R.StorerKey
      AND   LOC.Loc = R.ToLoc
      AND   SKU.PackKey = PACK.PackKey
      AND   (SKU.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')
      AND   R.Confirmed = 'N'
      AND   LOC.Facility = ISNULL(@c_zone01,'') -- SOS38086
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)
      ORDER BY LOC.PutawayZone, R.Priority
   END
   ELSE
   BEGIN
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, 
         SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey
      FROM REPLENISHMENT R, SKU WITH (NOLOCK), LOC WITH (NOLOCK), PACK WITH (NOLOCK) -- Pack table added by Jacob. Date: Jan 03, 2001
      WHERE SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey
      AND   LOC.Loc = R.ToLoc
      AND   SKU.PackKey = PACK.PackKey
      AND   (SKU.Storerkey = @c_storerkey OR @c_storerkey = 'ALL')
      AND   R.Confirmed = 'N'
      AND   LOC.Facility = ISNULL(@c_zone01,'') -- SOS38086
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)
      AND   LOC.PutawayZone IN (ISNULL(@c_zone02,''), ISNULL(@c_zone03,''), ISNULL(@c_zone04,''), 
                           ISNULL(@c_zone05,''), ISNULL(@c_zone06,''), ISNULL(@c_zone07,''), 
                           ISNULL(@c_zone08,''), ISNULL(@c_zone09,''), ISNULL(@c_zone10,''), ISNULL(@c_zone11,''), ISNULL(@c_zone12,''))           
      ORDER BY LOC.PutawayZone, R.Priority
   END
   SET NOCOUNT OFF
 END

GO