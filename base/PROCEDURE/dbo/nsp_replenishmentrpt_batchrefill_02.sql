SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure:  nsp_ReplenishmentRpt_BatchRefill_02                */  
/* Creation Date: 01-Aug-2006                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YokeBeen                                                 */  
/*                                                                      */  
/* Purpose:  NIKE China Wave Replenishment Report                       */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/* Input Parameters: @c_Zone1 - facility                                */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: r_replenishment_report02                                  */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 16-Jan-2007  Shong     Don't replenish grade B stock to pick face.   */  
/*                        Lottable02 = 02000 (Grade B)                  */  
/*                        SOS# 64895                                    */  
/* 14-May-2008  Shong     Full Carton Replenishment                     */  
/* 03-Jun-2008  Shong     Replace the Hardcode Grade B to Codelkup      */  
/*                        SOS#107158                                    */   
/* 02-07-2008   Shong     According to SOS#110598 User want to take     */  
/*                        the remaining Qty in the Bulk Location if Qty */  
/*                        less then 1 Carton                            */  
/* 23-Feb-2012  KHLim01   Reduce blocking                               */  
/* 05-Jun-2014  NJOW01    312492-Configurable mapping for desc & ID     */  
/* 20-Sep-2016  TLTING    Remove SetROWCOUNT                            */  
/* 05-MAR-2018 Wan01      WM - Add Functype                             */  
/* 05-OCT-2018 CZTENG01   WM - Add StorerKey,ReplGrp                    */  
/************************************************************************/  
CREATE PROC  [dbo].[nsp_ReplenishmentRpt_BatchRefill_02]  
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
,              @c_storerkey        NVARCHAR(15) = 'ALL'   --(CZTENG01)  
,     @c_ReplGrp          NVARCHAR(30) = 'ALL'   --(CZTENG01)  
,              @c_Functype         NCHAR(1) = ''          --(Wan01)  
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
  
   DECLARE @b_debug int,  
   @c_Packkey NVARCHAR(10),  
   @c_UOM     NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)  
   @n_qtytaken int,  
   @n_ROWREF   INT, -- KHLim01  
   @n_Rowcnt   INT, -- KHLim01  
   @n_ReplenishmentKey INT  -- KHLim01  
     
   SELECT @n_continue=1, @b_debug = 0  
   SELECT @n_starttcnt=@@TRANCOUNT  -- KHLim01  
  
   IF @c_zone12 <> ''  
      SELECT @b_debug = CAST( @c_zone12 AS int)  
  
   DECLARE @c_priority  NVARCHAR(5)  
     
   --(Wan01) - START  
   IF ISNULL(@c_ReplGrp,'') = ''  
   BEGIN  
      SET @c_ReplGrp = 'ALL'  
   END  
   --(Wan01) - END                
  
   IF @c_FuncType IN ( '','G' )                                      --(Wan01)  
   BEGIN     
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
         @n_SKULocAvailableQty int  
  
         SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),  
         @c_CurrentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),  
         @n_CurrentFullCase = 0   , @n_CurrentSeverity = 9999999 ,  
         @n_FromQty = 0, @n_remainingqty = 0, @n_PossibleCases = 0,  
         @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,  
         @n_limitrecs = 5  
        
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
            FROM SKUxLOC (NOLOCK)  
            JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC  
            JOIN SKU (NOLOCK) ON SKUxLOC.StorerKey = SKU.StorerKey AND  SKUxLOC.SKU = SKU.SKU  
            JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PACKKey   
            JOIN (SELECT SKUxLOC.STORERKEY, SKUxLOC.SKU, SKUxLOC.LOC   
                  FROM   SKUxLOC (NOLOCK)   
                  JOIN   LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC  
                  WHERE  SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0   
                  AND    SKUxLOC.LocationType NOT IN ('PICK','CASE')   
                  AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') --(Wan01)  
                  AND    LOC.FACILITY = @c_Zone01   
                  AND    LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') ) AS SL   
                  ON SL.STORERKEY = SKUxLOC.StorerKey AND SL.SKU = SKUxLOC.SKU   
            WHERE LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')  
            AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')  
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )  
            AND  LOC.FACILITY = @c_Zone01  
            AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)  
            -- AND  SKUxLOC.SKu = '272857555XL'  
  
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
            FROM SKUxLOC (NOLOCK)  
            JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC  
            JOIN SKU (NOLOCK) ON SKUxLOC.StorerKey = SKU.StorerKey AND  SKUxLOC.SKU = SKU.SKU  
            JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PACKKey   
            JOIN (SELECT SKUxLOC.STORERKEY, SKUxLOC.SKU, SKUxLOC.LOC   
                  FROM   SKUxLOC (NOLOCK)   
                  JOIN   LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC  
                  WHERE  SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > 0  
                  AND    SKUxLOC.LocationType NOT IN ('PICK','CASE')  
                  AND   (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  --(Wan01)  
                  AND    LOC.FACILITY = @c_Zone01   
                  AND    LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') ) AS SL   
                  ON SL.STORERKEY = SKUxLOC.StorerKey AND SL.SKU = SKUxLOC.SKU   
            WHERE LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')  
            AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')  
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum )  
            AND  LOC.FACILITY = @c_Zone01  
            AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)  
            AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')          --(Wan01)  
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
               SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15)  
               WHILE (1=1) -- while 3  
               BEGIN  
                  SELECT TOP 1 @c_CurrentStorer = StorerKey  
                  FROM #TempSKUxLOC  
                  WHERE StorerKey > @c_CurrentStorer  
                  AND ReplenishmentSeverity = @n_CurrentSeverity  
                  AND ReplenishmentPriority = @c_CurrentPriority  
                  ORDER BY StorerKey  
                 
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
  
                  -- 3-Sept-2004 YTWAN  NIKE BSWH Replenishment  - START  
                  SELECT @c_CurrentSKU = SPACE(20)  
                  WHILE (1=1) -- while 4  
                  BEGIN  
                     SELECT TOP 1 @c_CurrentSKU = SKU  
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
                        Print 'Working on @c_CurrentSKU:' + dbo.fnc_RTrim(@c_CurrentSKU)   
                     END   
                   
                     SELECT @c_CurrentLOC = SPACE(10)  
                     WHILE (1=1) -- while 4  
                     BEGIN  
                        SELECT TOP 1 @c_CurrentStorer = StorerKey ,  
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
                           BREAK  
                        END  
                       
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
                              
                        DECLARE     @c_uniquekey NVARCHAR(40), @c_uniquekey2 NVARCHAR(40)  
                       
                        SELECT @c_uniquekey = '', @c_uniquekey2 = ''  
  
                        SELECT TOP 1 @c_fromlot2 = LOTxLOCxID.LOT   
                        FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK), LOT (NOLOCK)   
                        WHERE LOTxLOCxID.LOT > @c_fromlot2  
                        AND LOTxLOCxID.StorerKey = @c_CurrentStorer  
                        AND LOTxLOCxID.SKU = @c_CurrentSKU  
                        AND LOTxLOCxID.LOC = LOC.LOC  
                        AND LOC.LocationFlag <> "DAMAGE"  
                        AND LOC.LocationFlag <> "HOLD"  
                        AND LOC.Status <> "HOLD"  
                        AND ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) - LOTxLOCxID.qty) > 0 -- SOS 6217  
                        AND LOTxLOCxID.LOC = @c_CurrentLOC  
                        AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT  
                        AND LOTxLOCxID.STORERKEY = LOTATTRIBUTE.STORERKEY  
                        AND LOTxLOCxID.SKU = LOTATTRIBUTE.SKU  
                        AND LOTxLOCxID.LOT = LOT.LOT  
                        AND LOT.Status <> "HOLD"  
                        AND LOC.Facility = @c_zone01   
                        AND LOTATTRIBUTE.Lottable02 NOT IN (SELECT CODELKUP.Code FROM CODELKUP WHERE Listname = 'GRADE_B') -- SOS#107158  
                        ORDER BY LOTxLOCxID.LOT   
     
                        IF @@ROWCOUNT = 0  
                        BEGIN  
     
                           SELECT TOP 1 @c_fromlot = LOTxLOCxID.LOT,  
                                  @c_fromloc = LOTxLOCxID.LOC,  
                                  @c_fromid  = LOTxLOCxID.ID,  
                                  @n_OnHandQty = LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked),  
                                  @c_uniquekey2= CASE LOC.LocationHandling   WHEN '2'  
                                                    THEN '05'  
                                                    WHEN '1'  
                                                    THEN '10'  
                                                    WHEN '9'  
                                                    THEN '15'  
                                                    ELSE '99'  
                                                END + RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) +   
                                                LOTxLOCxID.LOC + LOTxLOCxID.LOT + LOTxLOCxID.ID  
                           FROM LOTxLOCxID (NOLOCK)   
                                JOIN LOC (NOLOCK)     ON  (LOTxLOCxID.LOC = LOC.LOC)  
                                                      AND (LOC.LocationFlag <> "DAMAGE")  
                                                      AND (LOC.LocationFlag <> "HOLD")  
                                             --       AND (LOC.LocationType <> "BBA") -- added by Jeff - Do not replenish from BBA  
                                                      AND (LOC.Status <> "HOLD")  
                                JOIN SKUXLOC (NOLOCK) ON  (LOTxLOCxID.StorerKey = SKUXLOC.Storerkey)  
                                                      AND (LOTxLOCxID.SKU = SKUXLOC.SKU)  
                                                      AND (LOTxLOCxID.LOC = SKUXLOC.LOC)  
                                                      AND (SKUXLOC.LOCATIONTYPE <> "CASE")  
                                                      AND (SKUXLOC.LOCATIONTYPE <> "PICK")  
                                                      AND (SKUXLOC.QtyExpected = 0)  
                                JOIN ID (NOLOCK)      ON  (LOTxLOCxID.ID = ID.ID)  
                                                      AND (ID.Status <> "HOLD")  
                                JOIN LOT(NOLOCK)      ON  (LOTxLOCxID.LOT = LOT.LOT)  
                                                      AND (LOT.Status <> "HOLD")  
                                JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT -- SOS# 64895  
                           WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer  
                           AND LOTxLOCxID.SKU = @c_CurrentSKU  
                           AND LOTxLOCxID.LOC <> @c_CurrentLOC  
                           AND LOC.Facility   = @c_zone01  
                           AND LOTxLOCxID.Lot = @c_fromlot2  
                           AND ( LOTxLOCxID.qtyexpected = 0 )  
                           AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0   
                           AND NOT EXISTS ( SELECT 1  
                                            FROM CODELKUP (NOLOCK)   
                                            WHERE CODELKUP.Code = LOTATTRIBUTE.Lottable02  
                                            AND   CODELKUP.Listname = 'GRADE_B') -- SOS#107158  
                                            AND NOT EXISTS ( SELECT 1   
                                            FROM #REPLENISHMENT  
                                            WHERE #REPLENISHMENT.Lot     = LOTxLOCxID.LOT  
                                            AND   #REPLENISHMENT.FromLoc = LOTxLOCxID.LOC  
                                            AND   #REPLENISHMENT.ID      = LOTxLOCxID.ID  
         GROUP BY #REPLENISHMENT.Lot, #REPLENISHMENT.FromLoc, #REPLENISHMENT.ID  
                                            HAVING (LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked)) - SUM(#REPLENISHMENT.Qty) <= 0)  
                           ORDER BY CASE LOC.LocationType WHEN "BBA"   
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
                                    LOTxLOCxID.Qty, LOTxLOCxID.Loc ,LOTxLOCxID.Lot, LOTxLOCxID.ID DESC  
  
                                               
                           IF @@ROWCOUNT > 0  
                           BEGIN  
                              GOTO GET_REPLENISH_RECORD  
                           END  
                        END  
     
                        WHILE (1=1 AND @n_remainingqty > 0)  -- while 5  
                        BEGIN  
             
                              SELECT TOP 1 @c_fromlot = LOTxLOCxID.LOT,  
                                     @c_fromloc = LOTxLOCxID.LOC,  
                                     @c_fromid  = LOTxLOCxID.ID,  
                                     @n_OnHandQty = LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked),  
                                     @c_uniquekey = CASE LOC.LocationHandling   WHEN '2'  
                                                          THEN '05'  
                                                          WHEN '1'  
                                                          THEN '10'  
                                                          WHEN '9'  
                                                          THEN '15'  
                                                          ELSE '99'  
                                                      END + RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) +   
                                                      LOTxLOCxID.LOC + LOTxLOCxID.LOT  
                              FROM LOTxLOCxID (NOLOCK)   
                                   JOIN LOC (NOLOCK)     ON  (LOTxLOCxID.LOC = LOC.LOC)  
                                                         AND (LOC.LocationFlag <> "DAMAGE")  
                                                         AND (LOC.LocationFlag <> "HOLD")  
                                                      -- AND (LOC.LocationType <> "BBA") -- added by Jeff - Do not replenish from BBA   
                                                         AND (LOC.Status <> "HOLD")  
                                   JOIN SKUXLOC (NOLOCK) ON  (LOTxLOCxID.StorerKey = SKUXLOC.Storerkey)  
                                                         AND (LOTxLOCxID.SKU = SKUXLOC.SKU)  
                                                         AND (LOTxLOCxID.LOC = SKUXLOC.LOC)  
                         AND (SKUXLOC.LOCATIONTYPE <> "CASE")  
                                                         AND (SKUXLOC.LOCATIONTYPE <> "PICK")  
                                                         AND (SKUXLOC.QtyExpected = 0)  
                                   JOIN ID (NOLOCK)      ON  (LOTxLOCxID.ID = ID.ID)  
                         AND (ID.Status <> "HOLD")  
                                   JOIN LOT(NOLOCK)      ON  (LOTxLOCxID.LOT = LOT.LOT)  
                                                         AND (LOT.Status <> "HOLD")   
                                   JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT -- SOS# 64895  
                              WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer  
                    AND LOTxLOCxID.SKU = @c_CurrentSKU  
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC  
                              AND LOC.Facility   = @c_zone01  
                              AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0   
                              AND ( LOTxLOCxID.qtyexpected = 0 )  
                              AND NOT EXISTS ( SELECT 1  
                                            FROM CODELKUP (NOLOCK)   
                                            WHERE CODELKUP.Code = LOTATTRIBUTE.Lottable02  
                                            AND   CODELKUP.Listname = 'GRADE_B') -- SOS#107158  
                              AND ((( CASE LOC.LocationHandling   WHEN '2'  
                                           THEN '05'  
                                           WHEN '1'  
                                           THEN '10'  
                                           WHEN '9'  
                                           THEN '15'  
                                           ELSE '99'  
                                       END + RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) +   
                                             LOTxLOCxID.LOC + LOTxLOCxID.LOT >= @c_uniquekey AND LOTxLOCxID.Id < @c_fromid)  
                              OR ( CASE LOC.LocationHandling   WHEN '2'  
                                           THEN '05'  
                                           WHEN '1'  
                                           THEN '10'  
                                           WHEN '9'  
                                           THEN '15'  
                                           ELSE '99'  
                                       END + RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) +   
                                             LOTxLOCxID.LOC + LOTxLOCxID.LOT > @c_uniquekey ))   
                              AND (CASE LOC.LocationHandling   WHEN '2'  
                                                    THEN '05'  
                                                    WHEN '1'  
                                                    THEN '10'  
                                                    WHEN '9'  
                                                    THEN '15'  
                                                    ELSE '99'  
                                                END + RIGHT(dbo.fnc_RTrim('000000000000000000'+ CAST(LOTxLOCxID.Qty AS NVARCHAR(18))),18) +   
                                                LOTxLOCxID.LOC + LOTxLOCxID.LOT + LOTxLOCxID.ID <> @c_uniquekey2 ))  
                              AND NOT EXISTS ( SELECT 1   
                                            FROM #REPLENISHMENT  
                                            WHERE #REPLENISHMENT.Lot     = LOTxLOCxID.LOT  
                                            AND   #REPLENISHMENT.FromLoc = LOTxLOCxID.LOC  
                                            AND   #REPLENISHMENT.ID      = LOTxLOCxID.ID  
                                           GROUP BY #REPLENISHMENT.Lot, #REPLENISHMENT.FromLoc, #REPLENISHMENT.ID   
                                            HAVING (LOTxLOCxID.Qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked)) - SUM(#REPLENISHMENT.Qty) <= 0  )  
                              ORDER BY CASE LOC.LocationType WHEN "BBA"   
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
  LOTxLOCxID.Qty, LOTxLOCxID.Loc ,LOTxLOCxID.Lot, LOTxLOCxID.ID DESC  
                           
                             
  
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
                                    SELECT 'Lot picked from LOTxLOCxID' , @c_fromlot  
                                 END  
                              END   
  
                              IF @b_debug = 1  
                                 BEGIN  
  
                                    SELECT LOT, FROMLOC, ID, @n_OnHandQty - SUM(#REPLENISHMENT.Qty), @n_OnHandQty onhandqty, SUM(#REPLENISHMENT.Qty) replqty     
                                    from  #REPLENISHMENT  
                                    where #REPLENISHMENT.Lot     = @c_fromlot  
                                    AND   #REPLENISHMENT.FromLoc = @c_fromloc  
                                    AND   #REPLENISHMENT.ID      = @c_fromid  
                                    group by #REPLENISHMENT.Lot, #REPLENISHMENT.FromLoc, #REPLENISHMENT.ID   
                                 END  
                              IF @b_debug = 1  
                              BEGIN  
                                 SELECT 'Selected Lot' , @c_fromlot  
                              END  
                      
                              GET_REPLENISH_RECORD:  
  
                              SELECT @n_OnHandQty = @n_OnHandQty - SUM(#REPLENISHMENT.Qty)  
                              FROM  #REPLENISHMENT  
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
                                 -- Take Full Case if the qty need to replenish < carton  
                                 IF @n_OnHandQty >= @n_CurrentFullCase AND @n_RemainingQty <= @n_CurrentFullCase  
                                 BEGIN   
                                    SET @n_FromQty = @n_CurrentFullCase  
                                    SELECT @n_RemainingQty = 0  
                                 END              
                                 ELSE IF @n_OnHandQty >= @n_CurrentFullCase AND @n_RemainingQty > @n_CurrentFullCase  
                                 BEGIN   
                                    SELECT @n_PossibleCases = floor(@n_RemainingQty / @n_CurrentFullCase)  
                                    IF (@n_RemainingQty / @n_CurrentFullCase) > @n_PossibleCases AND  
                                       (@n_PossibleCases * @n_CurrentFullCase) < @n_RemainingQty  
                                    BEGIN  
                                       -- take one more case  
                               SET @n_PossibleCases = @n_PossibleCases + 1  
                                    END  
  
                                    SELECT @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase)  
  
                                    SELECT @n_RemainingQty = 0  
                                 END              
                                 ELSE   
                                 BEGIN   
                                    -- By SHONG SOS#110598  
                                    -- User want to take all the remaining Qty in the Bulk  
                                    -- Location if it less then 1 Carton   
                                    -- SELECT @n_FromQty = @n_RemainingQty  
                                    IF @n_OnHandQty <= @n_CurrentFullCase  
                                    BEGIN  
                                       SELECT @n_FromQty = @n_OnHandQty    
                                    END  
                                    ELSE  
                                    BEGIN   
                                       SELECT @n_FromQty = @n_RemainingQty   
                                    END  
                                    SELECT @n_RemainingQty = 0  
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
  
                                    SELECT @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase)  
                                 END  
                                 ELSE  
                                 BEGIN  
                                    -- Added By SHONG on 13th May 2008  
                                    IF @n_OnHandQty = (SELECT SUM(Qty - QtyAllocated - QtyPicked)   
                                                       FROM LOTxLOCxID (NOLOCK) WHERE LOT = @c_fromlot  
                                                       AND   Loc = @c_fromloc  
                                                       AND   ID  = @c_fromid )   
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
                                    SELECT '@n_possiblecases' = @n_possiblecases , '@n_currentFullCase' = @n_currentFullCase  
                                    SELECT '@n_FromQty' = @n_FromQty  
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
                       
                           END -- SCAN LOT FOR LOT  
                        END  -- FOR LOC  
                     END -- FOR SKU  
                     -- 3-Sept-2004 YTWAN  NIKE BSWH Replenishment  - END  
                  END -- FOR STORER  
               END -- FOR SEVERITY  
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
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to get REPLENISHKEY. (nsp_ReplenishmentRpt_BatchRefill_02)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
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
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into Replenishment table failed. (nsp_ReplenishmentRpt_BatchRefill_02)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishmentRpt_BatchRefill_02'  
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
      SELECT R.FromLoc,   
      CASE WHEN ISNULL(CLR.Code,'') <> '' THEN SKU.AltSKU ELSE R.Id END AS ID, --NJOW01  
      R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,  
      CASE WHEN ISNULL(CLR.Code,'') <> '' THEN RTRIM(ISNULL(SKU.Style,'')) + ' ' + RTRIM(ISNULL(SKU.Color,'')) + ' ' + RTRIM(ISNULL(SKU.Size,'')) ELSE SKU.Descr END AS Descr, --NJOW01  
      R.Priority, L1.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey,   
      (LT.Qty - LT.QtyAllocated - LT.QtyPicked), LA.Lottable02, LA.Lottable04        
      FROM  REPLENISHMENT R (NOLOCK)  
            JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey  
            JOIN LOC L1 (NOLOCK) ON L1.Loc = R.ToLoc  
            JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey   
            JOIN LOC L2 (nolock) ON L2.Loc = R.FromLoc  
            JOIN LOTxLOCxID LT (nolock) ON LT.Lot = R.Lot AND LT.Loc = R.FromLoc AND LT.ID = R.ID  
            JOIN LOTATTRIBUTE LA (NOLOCK) ON LT.SKU = LA.SKU AND LT.STORERKEY = LA.STORERKEY AND LT.LOT = LA.LOT -- Pack table added by Jacob Date Jan 03, 2001  
            LEFT JOIN Codelkup CLR (NOLOCK) ON (R.Storerkey = CLR.Storerkey AND CLR.Code = 'CUSTOM_MAP_DESC_ID'     
                                                AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_replenishment_report02' AND ISNULL(CLR.Short,'') <> 'N') --NJOW01             
      WHERE R.confirmed = 'N'  
      AND  L1.Facility = @c_zone01  
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)  
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)  
      ORDER BY L1.PutawayZone, R.Priority  
   END  
   ELSE  
   BEGIN  
      SELECT R.FromLoc,   
      CASE WHEN ISNULL(CLR.Code,'') <> '' THEN SKU.AltSKU ELSE R.Id END AS ID, --NJOW01  
      R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,  
      CASE WHEN ISNULL(CLR.Code,'') <> '' THEN RTRIM(ISNULL(SKU.Style,'')) + ' ' + RTRIM(ISNULL(SKU.Color,'')) + ' ' + RTRIM(ISNULL(SKU.Size,'')) ELSE SKU.Descr END AS Descr, --NJOW01  
      R.Priority, L1.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, (LT.Qty - LT.QtyAllocated - LT.QtyPicked), LA.Lottable02, LA.Lottable04  
      FROM  REPLENISHMENT R (NOLOCK)  
            JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey  
            JOIN LOC L1 (NOLOCK) ON L1.Loc = R.ToLoc  
            JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey   
            JOIN LOC L2 (nolock) ON L2.Loc = R.FromLoc  
            JOIN LOTxLOCxID LT (nolock) ON LT.Lot = R.Lot AND LT.Loc = R.FromLoc AND LT.ID = R.ID  
            JOIN LOTATTRIBUTE LA (NOLOCK) ON LT.SKU = LA.SKU AND LT.STORERKEY = LA.STORERKEY AND LT.LOT = LA.LOT -- Pack table added by Jacob Date Jan 03, 2001                        
            LEFT JOIN Codelkup CLR (NOLOCK) ON (R.Storerkey = CLR.Storerkey AND CLR.Code = 'CUSTOM_MAP_DESC_ID'     
                                                AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_replenishment_report02' AND ISNULL(CLR.Short,'') <> 'N')  --NJOW01            
      WHERE R.confirmed = 'N'  
      AND  L1.Facility = @c_zone01  
      AND   L1.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)  
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)  
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)  
      ORDER BY L1.PutawayZone, R.Priority  
   END  
   QUIT_SP:                --(Wan01)  
END  

GO