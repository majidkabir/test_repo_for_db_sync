SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: isp_ReplenishmentRpt_PC21                             */  
/* Creation Date: 22-Jul-2015                                              */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: SOS#346269 - Taiwan HHT Replenishment Report.                  */  
/*                       Amend From nsp_ReplenishmentRpt_PC14              */  
/*                                                                         */  
/* Called By: Replenishment Report r_replenishment_report_PC21             */  
/*                                                                         */  
/* PVCS Version: 1.1                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author   Ver   Purposes                                     */  
/* 05-MAR-2018 Wan01    1.1   WM - Add Functype                            */
/***************************************************************************/  
CREATE PROC [dbo].[isp_ReplenishmentRpt_PC21]  
               @c_Zone01      NVARCHAR(10)  
,              @c_Zone02      NVARCHAR(10)  
,              @c_Zone03      NVARCHAR(10)  
,              @c_Zone04      NVARCHAR(10)  
,              @c_Zone05      NVARCHAR(10)  
,              @c_Zone06      NVARCHAR(10)  
,              @c_Zone07      NVARCHAR(10)  
,              @c_Zone08      NVARCHAR(10)  
,              @c_Zone09      NVARCHAR(10)  
,              @c_Zone10      NVARCHAR(10)  
,              @c_Zone11      NVARCHAR(10)  
,              @c_Zone12      NVARCHAR(10)  
,              @c_Storerkey   NVARCHAR(15) = ''      
,              @c_ReplGrp     NVARCHAR(30) = 'ALL'     --(Wan01)  
,              @c_Functype    NCHAR(1) = ''            --(Wan01)  
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
     
   DECLARE @b_debug INT
          ,@c_Packkey NVARCHAR(10)
          ,@c_UOM NVARCHAR(10) -- SOS 8935 wally 13.dec.2002 From NVARCHAR(5) to NVARCHAR(10)
          ,@n_FullPallet INT
          ,@n_PalletCnt INT   

   DECLARE @cLocationHandling NVARCHAR(10)
          ,@n_FullCaseQty INT   

   DECLARE @c_CurrentSKU NVARCHAR(20)
          ,@c_CurrentStorer NVARCHAR(15)
          ,@c_CurrentLoc NVARCHAR(10)
          ,@c_CurrentPriority NVARCHAR(5)
          ,@n_CurrentFullCase INT
          ,@n_CurrentSeverity INT
          ,@c_FromLoc NVARCHAR(10)
          ,@c_Fromlot NVARCHAR(10)
          ,@c_Fromid NVARCHAR(18)
          ,@n_FromQty INT
          ,@n_RemainingQty INT
          ,@n_PossibleCases INT
          ,@n_RemainingCases INT
          ,@n_OnHandQty INT
          ,@n_FromCases INT
          ,@c_ReplenishmentKey NVARCHAR(10)
          ,@n_NumberOfRecs INT
          ,@n_LimitRecs INT
          ,@c_Fromlot2 NVARCHAR(10)
          ,@b_DoneCheckOverAllocatedLots INT
          ,@c_HostWHCode NVARCHAR(10)  -- sos 2199
          ,@c_OverAllocation NVARCHAR(1) 
          ,@d_MinLottable04 DATETIME  
          ,@d_CurrLottable04 DATETIME
          ,@n_CaseCnt INT
          ,@n_QtyExpedted INT
          ,@d_CurrLottable05 DATETIME
          ,@n_QtyOverAllocated INT
          ,@n_Priority INT
          ,@c_LastReplenLoc NVARCHAR(10)
      
   DECLARE @c_priority  NVARCHAR(5)

   DECLARE @b_success   INT
          ,@n_err       INT
          ,@c_errmsg    NVARCHAR(255)
                                            
   SELECT @n_continue=1,  
   @b_debug = 0
  
   IF @c_Zone12 = '1'  
   BEGIN  
      SELECT @b_debug = CAST( @c_Zone12 AS int)  
      SELECT @c_Zone12 = ''  
   END  

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
       
   SELECT StorerKey, SKU, LOC FromLOC, LOC ToLOC, Lot, Id, Qty, Qty QtyMoved, Qty QtyInPickLOC,  
   @c_priority Priority, Lot UOM, Lot PackKey  
   INTO #REPLENISHMENT  
   From LOTXLOCXID (NOLOCK)  
   WHERE 1 = 2  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),  
      @c_CurrentLoc = SPACE(10), @c_CurrentPriority = SPACE(5),  
      @n_CurrentFullCase = 0   , @n_CurrentSeverity = 9999999 ,  
      @n_FromQty = 0, @n_RemainingQty = 0, @n_PossibleCases = 0,  
      @n_RemainingCases =0, @n_FromCases = 0, @n_NumberOfRecs = 0,  
      @n_LimitRecs = 5, @n_QtyExpedted=0  
      /* Make a temp version of SKUxLOC */  
      SELECT ReplenishmentPriority, ReplenishmentSeverity ,StorerKey,  
      SKU, LOC, ReplenishmentCasecnt, 'N' AS OverAllocation, 0 AS QtyExpected   
      INTO #TempSKUxLOC  
      From SKUxLOC (NOLOCK)  
      WHERE 1=2  
  
      INSERT #TempSKUxLOC  
      SELECT ReplenishmentPriority,  
--      ReplenishmentSeverity = CASE WHEN SUM(LOTxLOCxID.QtyExpected) > 0   
--                                     AND SKUxLOC.QtyLocationMinimum < (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated)) THEN    
--                                              SUM(LOTxLOCxID.QtyExpected)  
--                                   ELSE SKUxLOC.QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))  
--                              END,  
      ReplenishmentSeverity = CASE 
                                 WHEN ISNULL(sc.SValue, '0') = '1' THEN
                                    0  -- Set to Zero so that the Qty To Replen is using TotalQtyAllocated calculate at below section
                                    -- SUM(LOTxLOCxID.QtyExpected) 
                                 WHEN SUM(LOTxLOCxID.QtyExpected) > 0 AND 
                                    (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated > SKUxLOC.QtyLocationMinimum ) THEN    
                                    SUM(LOTxLOCxID.QtyExpected)   
                                 ELSE 
                                    SKUxLOC.QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))  
                              END,  
      SKUxLOC.StorerKey,  
      SKUxLOC.SKU,  
      SKUxLOC.LOC,  
      ReplenishmentCasecnt,  
      OverAllocation = CASE WHEN SUM(LOTxLOCxID.QtyExpected) > 0   
                              OR SKUxLOC.QtyLocationMinimum < (SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated)) THEN   -- SHONG02
                                 'Y'  
                            ELSE 'N' END,
      ISNULL(SUM(LOTxLOCxID.QtyExpected),0) 
      From SKUxLOC (NOLOCK) 
      JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
      JOIN SKU (NOLOCK) ON SKU.StorerKey = SKUxLOC.StorerKey  
                               AND  SKU.SKU = SKUxLOC.SKU 
      LEFT OUTER JOIN StorerConfig sc (NOLOCK) ON sc.StorerKey = SKUxLOC.StorerKey AND sc.ConfigKey = 'OnlyReplenOverAllocQty' AND sc.SValue = '1'
      LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey  
                               AND  SKUxLOC.Sku = LOTxLOCxID.Sku  
                               AND  SKUxLOC.Loc = LOTxLOCxID.Loc                        
      WHERE  (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')  
      AND  LOC.Facility = @c_Zone01  
      AND  (LOC.PutawayZone in (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)  
            OR @c_Zone02 = 'ALL')  
      AND  SKUxLOC.StorerKey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                       SKUxLOC.StorerKey ELSE @c_StorerKey END      
      GROUP BY SKUxLOC.ReplenishmentPriority,  
               SKUxLOC.StorerKey,  
               SKUxLOC.SKU,  
               SKUxLOC.LOC,  
               SKUxLOC.ReplenishmentCasecnt,  
               SKUxLOC.Qty,  
               SKUxLOC.QtyPicked,  
               SKUxLOC.QtyAllocated,  
               SKUxLOC.QtyLocationMinimum,  
               SKUxLOC.QtyLocationLimit, 
               ISNULL(sc.SValue, '0')  
      HAVING SUM(ISNULL(LOTxLOCxID.QtyExpected,0)) > 0 OR   
            ( (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated <= SKUxLOC.QtyLocationMinimum ) AND ISNULL(sc.SValue, '0') = '0')  
  
      -- Remarked by June 18.Nov.04 : SOS29580  
      /* Loop through SKUxLOC for the CurrentSKU, Current storer */  
      /* to pickup the next severity */  
      SELECT @c_CurrentSKU = SPACE(20),  
             @c_CurrentLoc = SPACE(10)  
      WHILE (1=1)  
      BEGIN  
          SET @c_LastReplenLoc = ''
         SELECT TOP 1
                @c_CurrentStorer = StorerKey ,  
                @c_CurrentSKU = SKU,  
                @c_CurrentLoc = LOC,  
                @n_CurrentFullCase = ReplenishmentCasecnt,  
                @n_CurrentSeverity = ReplenishmentSeverity,  
                @c_OverAllocation = OverAllocation, 
                @n_QtyExpedted    = QtyExpected
         From #TempSKUxLOC  
         WHERE SKU > @c_CurrentSKU  
         ORDER BY SKU  
         
         IF @@ROWCOUNT = 0  
         BEGIN   
            BREAK  
         END  

         IF @b_debug = 1  
         BEGIN 
            SELECT @c_CurrentStorer '@c_CurrentStorer', @c_CurrentSKU '@c_CurrentSKU',  @c_CurrentLoc '@c_CurrentLoc'
         END 
               
         SELECT @c_Packkey = PACK.PackKey,  
                @c_UOM = PACK.PackUOM3, 
                @n_CaseCnt = ISNULL(PACK.CaseCnt,0), 
                @n_PalletCnt = ISNULL(PACK.Pallet, 0)   
         From   SKU (NOLOCK), PACK (NOLOCK)   
         WHERE  SKU.PackKey = PACK.Packkey  
         AND    SKU.StorerKey = @c_CurrentStorer  
         AND    SKU.SKU = @c_CurrentSKU  
                              
         SET @d_MinLottable04 = NULL 
         
         SELECT TOP 1 
               @d_MinLottable04 = LA.Lottable04
         FROM LOTxLOCxID lli WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = lli.Lot 
         WHERE lli.StorerKey = @c_CurrentStorer 
         AND lli.Sku = @c_CurrentSKU 
         AND lli.Loc = @c_CurrentLoc 
         AND (lli.Qty > 0 OR lli.QtyExpected > 0)
         ORDER BY LA.Lottable04 

         IF @b_debug = 1  
         BEGIN 
            SELECT @c_CurrentStorer '@c_CurrentStorer', @c_CurrentSKU '@c_CurrentSKU',  @c_CurrentLoc '@c_CurrentLoc'
         END 
                    
         -- SOS 2199 for Taiwan  
         -- start: 2199  
         select @c_HostWHCode = HostWHCode  
         From LOC (nolock)  
         WHERE LOC = @c_CurrentLoc  
         
         -- end: 2199  
         /* We now have a pickLocation that needs to be replenished! */  
         /* Figure out which Locations in the warehouse to pull this product From */  
         /* End figure out which Locations in the warehouse to pull this product From */  
         SELECT @c_FromLoc = SPACE(10)
               ,@c_FromLot = SPACE(10)
               ,@c_Fromid = SPACE(18)
               ,@n_FromQty = 0
               ,@n_PossibleCases = 0
               ,@n_RemainingQty = @n_CurrentSeverity  -- Modify by SHONG on 29th Sep 2006
               ,@n_RemainingCases = CASE 
                                         WHEN @n_CurrentFullCase > 0 THEN @n_CurrentSeverity / @n_CurrentFullCase
                                         ELSE @n_CurrentSeverity
                                    END
               ,@c_Fromlot2 = SPACE(10)
               ,@b_DoneCheckOverAllocatedLots = 0    
         SELECT LOTxLOCxID.LOT, SUM((LOTxLOCxID.QtyPicked + LOTxLOCxID.QtyAllocated) - LOTxLOCxID.Qty) AS [QtyOverAllocated], LA.Lottable04, LA.Lottable05  
         INTO #TMP_OVERALLOC  
         From LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC  
         JOIn LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.Lot 
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = LOT.Lot   
         WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer  
         AND LOTxLOCxID.SKU = @c_CurrentSKU  
         AND LOTxLOCxID.Qty < (LOTxLOCxID.QtyPicked + LOTxLOCxID.QtyAllocated)    
         AND LOTxLOCxID.LOC = @c_CurrentLoc  
         AND LOT.Status     = 'OK'       
         GROUP BY LOTxLOCxID.LOT, LA.Lottable04, LA.Lottable05     

           
         DECLARE LOT_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT 1 AS Priority, LOT, [QtyOverAllocated], LOTTABLE04, LOTTABLE05
         FROM   #TMP_OVERALLOC 
         UNION ALL 
         SELECT 2 AS Priority, LOTxLOCxID.LOT, 0 AS [QtyOverAllocated]
            , LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05    
         From LOTxLOCxID (NOLOCK)  
         JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC  
         JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.LOT = LOTATTRIBUTE.LOT  
         JOIN LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.Lot  
         LEFT OUTER JOIN ID (NOLOCK) ON LOTxLOCxID.ID  = ID.ID  
         -- LEFT JOIN #TMP_OVERALLOC ON LOTxLOCxID.Lot = #TMP_OVERALLOC.Lot  
         WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer  
         AND LOTxLOCxID.SKU = @c_CurrentSKU  
         AND LOC.LocationFlag <> 'DAMAGE'  
         AND LOC.LocationFlag <> 'HOLD'  
         AND LOC.Status <> 'HOLD'  
         AND LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0  
         AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull From a Location that needs stuff to satisfy existing demand  
         AND LOTxLOCxID.LOC <> @c_CurrentLoc  
         AND LOC.Facility = @c_Zone01  
         AND LOC.HostWHCode = @c_HostWHCode -- sos 2199  
         AND LOT.Status     = 'OK'     -- Added By YTWan on 07-Oct-2004  
         AND ISNULL(ID.Status ,'')  <> 'HOLD'       -- Added By YTWan on 07-Oct-2004  
         AND ISNULL(LOTATTRIBUTE.LOTTABLE04,'') = CASE WHEN @d_MinLottable04 IS NOT NULL THEN @d_MinLottable04 ELSE ISNULL(LOTATTRIBUTE.LOTTABLE04,'') END
         GROUP BY LOTxLOCxID.LOT, LOTTABLE04, LOTTABLE05     
         ORDER BY Priority, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05, LOTxLOCxID.LOT 
    
         OPEN LOT_CUR  
  
         FETCH NEXT FROM LOT_CUR INTO @n_Priority, @c_FromLot, @n_QtyOverAllocated, @d_CurrLottable04, @d_CurrLottable05   
         WHILE @@FETCH_STATUS <> -1 AND (@n_RemainingQty > 0  OR @n_QtyOverAllocated > 0)   
         BEGIN   
            IF (@n_RemainingQty = 0 OR @n_RemainingQty < @n_QtyOverAllocated) AND @n_QtyOverAllocated > 0
               SET @n_RemainingQty = @n_QtyOverAllocated
               
            IF @b_debug = 1  
            BEGIN 
               SELECT @c_Fromlot '@c_Fromlot', CONVERT(VARCHAR(12), @d_CurrLottable04, 101) '@d_CurrLottable04', 
                      CONVERT(VARCHAR(12), @d_MinLottable04, 101) '@d_MinLottable04', 
                      @c_OverAllocation '@c_OverAllocation', @c_lastreplenloc '@c_lastreplenloc'
            END 
                     
            SELECT @c_FromLoc = SPACE(10)   
                        
            DECLARE LOC_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
               SELECT LOTxLOCxID.LOC  
               FROM LOTxLOCxID (NOLOCK)
               JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC  
               WHERE LOT = @c_Fromlot    
               AND StorerKey = @c_CurrentStorer  
               AND SKU = @c_CurrentSKU    
               AND LOC.LocationFlag <> 'DAMAGE'  
               AND LOC.LocationFlag <> 'HOLD'  
               AND LOC.Status <> 'HOLD'  
               AND LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated > 0  
               AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull From a Location that needs stuff to satisfy existing demAND  
               AND LOTxLOCxID.LOC <> @c_CurrentLoc  
               AND LOC.Facility = @c_Zone01   
               AND LOC.HostWHCode = @c_HostWHCode -- sos 2199  
               AND (LOC.PutawayZone in (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)  
               OR @c_Zone02 = 'ALL')  
               GROUP BY LOC.LogicAllocation, LOTxLOCxID.LOC  
               ORDER BY CASE WHEN SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated) < @n_PalletCnt THEN 0 ELSE 1 END,
                        LOC.LogicAllocation, LOTxLOCxID.LOC
               --ORDER BY SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated),  
               --          LOC.LogicAllocation, LOTxLOCxID.LOC 
                           
            OPEN LOC_CUR   
              
            FETCH NEXT From LOC_CUR INTO @c_FromLoc   
     
            WHILE @@Fetch_Status <> -1 AND @n_RemainingQty > 0   
            BEGIN    
                IF @c_LastReplenLoc <> @c_FromLoc AND ISNULL(@c_LastReplenLoc,'') <> ''
                   GOTO FIND_NEXT_LOC
                
               SELECT @c_Fromid = REPLICATE('Z',18)  
               WHILE (1=1 AND @n_RemainingQty > 0)  
               BEGIN  
                  SELECT TOP 1
                         @c_Fromid = ID,  
                         @n_OnHandQty = LOTxLOCxID.Qty - QtyPicked - QtyAllocated  
                  From LOTxLOCxID (NOLOCK), LOC (NOLOCK)  
                  WHERE LOT = @c_Fromlot  
                  AND LOTxLOCxID.LOC = LOC.LOC   
                  AND LOTxLOCxID.LOC = @c_FromLoc  
                  AND id < @c_Fromid  
                  AND StorerKey = @c_CurrentStorer  
                  AND SKU = @c_CurrentSKU  
                  AND LOC.LocationFlag <> 'DAMAGE'  
                  AND LOC.LocationFlag <> 'HOLD'  
                  AND LOC.Status <> 'HOLD'  
                  AND LOTxLOCxID.Qty - QtyPicked - QtyAllocated > 0  
                  AND LOTxLOCxID.QtyExpected = 0 -- make sure we aren't going to try to pull From a Location that needs stuff to satisfy existing demAND  
                  AND LOTxLOCxID.LOC <> @c_CurrentLoc  
                  AND LOC.Facility = @c_Zone01  
                  AND LOC.HostWHCode = @c_HostWHCode -- sos 2199  
                  ORDER BY ID DESC  
                       
                  IF @@ROWCOUNT = 0  
                  BEGIN  
                     IF @b_debug = 1  
                     BEGIN  
                        SELECT 'Stop because No Pallet Found! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU + ' LOT = ' + @c_Fromlot + ' From LOC = ' + @c_FromLoc  
                        + ' From ID = ' + @c_Fromid +  ' HostWHCode = ' + @c_HostWHCode 
                     END   
                     GOTO FIND_NEXT_LOC -- SOS#129030  
                  END  
  
                  IF EXISTS(SELECT 1 From ID (NOLOCK) WHERE ID = @c_Fromid  
                            AND STATUS = 'HOLD')  
                  BEGIN  
                     IF @b_debug = 1  
                     BEGIN  
                        SELECT 'Stop because ID Status = HOLD! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU + ' ID = ' + @c_Fromid  
                     END  
                     CONTINUE -- Should Try Another ID instead of Terminate  
                  END  
                  /* Verify that the From Location is not overallocated in SKUxLOC */  
                  IF EXISTS(SELECT 1 From SKUxLOC (NOLOCK)  
                            WHERE StorerKey = @c_CurrentStorer  
                            AND SKU = @c_CurrentSKU  
                            AND LOC = @c_FromLoc  
                            AND QtyExpected > 0  
                  )  
                  BEGIN  
                     IF @b_debug = 1  
                     BEGIN  
                        SELECT 'Stop because Qty Expected > 0! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU  
                     END  
                       
                     BREAK -- Get out of loop, so that next candidate can be evaluated  
                  END  
                  /* Verify that the From Location is not the */  
                  /* PIECE PICK Location for this product.    */  
                  IF EXISTS(SELECT 1 From SKUxLOC (NOLOCK)  
                            WHERE StorerKey = @c_CurrentStorer  
                            AND SKU = @c_CurrentSKU  
                            AND LOC = @c_FromLoc  
                            AND LocationType IN ('PICK', 'CASE')  
                  )  
                  BEGIN  
                     IF @b_debug = 1  
                     BEGIN  
                        SELECT 'Stop because Location Type = PICK/CASE! LOC = ' + @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU  
                     END  
                     BREAK -- Get out of loop, so that next candidate can be evaluated  
                  END  
 
                  SELECT @cLocationHandling = LocationHandling   
                  From   LOC (NOLOCK)   
                  WHERE  LOC = @c_CurrentLoc   
  
                  SET @n_FullCaseQty = 0  
                  SET @n_FullPallet = 0  

                  /* At this point, get the available Qty From */  
                  /* the SKUxLOC record.                       */  
                  /* If it's less than what was taken From the */  
                  /* lotxLOCxid record, then use it.           */  
                  SELECT @n_FullPallet = (Qty - QtyAllocated - QtyPicked)  
                  From LOTxLOCxID (NOLOCK)  
                  WHERE StorerKey = @c_CurrentStorer  
                  AND SKU = @c_CurrentSKU  
                  AND LOC = @c_FromLoc  
                  AND LOT = @c_Fromlot  
                  AND ID  = @c_Fromid  

                  IF @n_PalletCnt > 0 AND @n_FullPallet > @n_PalletCnt   
                  BEGIN  
                     SET @n_FullPallet = FLOOR(@n_FullPallet / @n_PalletCnt) * @n_PalletCnt  
                  END
                  
                  IF @n_CaseCnt = 0 OR @n_OnHandQty < @n_CaseCnt 
                     SET @n_FullCaseQty =  @n_OnHandQty 
                  ELSE 
                     SET @n_FullCaseQty =  @n_CaseCnt 

                  /* How many do we take? */  
                  --IF @cLocationHandling = '2' -- Case Only 
                  -- If the Lot suggested is not the earliest Lottable04 then only replen cartons   
--                  IF @d_CurrLottable04 > @d_MinLottable04 
--                     AND @c_OverAllocation = 'Y' 
--                     AND @d_CurrLottable04 IS NOT NULL 
--                     AND @d_MinLottable04 IS NOT NULL 
--                     AND 1=2  
--                  BEGIN   
--                     IF @n_RemainingQty >= @n_FullCaseQty  
--                     BEGIN  
--                        SELECT @n_FromQty = @n_FullCaseQty,  
--                               @n_RemainingQty = @n_RemainingQty - @n_FullCaseQty,
--                               @n_QtyExpedted = @n_QtyExpedted - @n_FullCaseQty  
--                     END  
--                     ELSE  
--                     BEGIN  
--                        -- Shong   
--                        -- Force to replen full case  
--                        IF @n_CurrentFullCase > 0 AND @n_CurrentFullCase > @n_FullCaseQty   
--                        BEGIN   
--                           -- get full case Qty   
--                           SELECT @n_PossibleCases = FLOOR(@n_RemainingQty / @n_CurrentFullCase)  
--                             
--                           -- trade remaining Qty as 1 full case  
--                           IF @n_RemainingQty % @n_CurrentFullCase > 0   
--                              SET @n_PossibleCases = @n_PossibleCases + 1  
--  
--                           SELECT @n_FullCaseQty = @n_PossibleCases * @n_CurrentFullCase   
--  
--                           IF @n_FullCaseQty > @n_RemainingQty    
--                              SET @n_FullCaseQty = @n_RemainingQty    
--                        END   
--                        ELSE   
--                           SELECT @n_FullCaseQty = @n_RemainingQty  
--  
--                        SELECT @n_FromQty = @n_FullCaseQty,  
--                               @n_RemainingQty = @n_RemainingQty - @n_FullCaseQty, 
--                               @n_QtyExpedted = @n_QtyExpedted - @n_FullCaseQty  
--                     END  
--                  END      
--                  ELSE  
                  BEGIN  
                     --IF @n_RemainingQty >= @n_FullPallet  
                     --BEGIN  
                     IF @n_Priority = 1 AND @n_QtyOverAllocated > 0 
                     BEGIN
                        SELECT @n_FromQty      = @n_FullPallet,  
                               @n_RemainingQty = @n_RemainingQty - @n_FullPallet,
                               @n_QtyExpedted  = @n_QtyExpedted  - @n_FullPallet,
                               @n_QtyOverAllocated = @n_QtyOverAllocated - @n_FullPallet
                        
                        IF @n_QtyOverAllocated <= 0 
                           SET @n_RemainingQty = 0     
                     END
                     ELSE
                     BEGIN
                        SELECT @n_FromQty      = @n_FullPallet,  
                               @n_RemainingQty = @n_RemainingQty - @n_FullPallet,
                               @n_QtyExpedted  = @n_QtyExpedted  - @n_FullPallet 
                        
                        -- Only Replen up to OverAllocated Qty (Total Expected Qty)
                        --IF @c_OverAllocation <> 'Y' OR @n_QtyExpedted <= 0 -- SHONG02
                        --   SET @n_RemainingQty = 0                        
                     END
                     --END  
                     --ELSE  
                     --BEGIN  
                        -- Shong   
                        -- Force to replen full pallet  
                        --SELECT @n_FromQty = 0  
                     --END  
                  END   
  
                  IF @b_debug = 1  
                  BEGIN  
                     SELECT @n_CurrentSeverity '@n_CurrentSeverity', @n_FullPallet '@n_FullPallet',   
                            @n_FullCaseQty '@n_FullCaseQty', @n_OnHandQty '@n_OnHandQty', @n_CurrentFullCase '@n_CurrentFullCase',   
                            @n_RemainingQty '@n_RemainingQty', @cLocationHandling '@cLocationHandling'
                     IF @n_Priority = 1
                        SELECT @n_QtyOverAllocated '@n_QtyOverAllocated'                              
                  END  
  
  
                  IF @n_FromQty > 0  
                  BEGIN  
 
                     IF @n_continue = 1 or @n_continue = 2  
                     BEGIN  
                        IF NOT EXISTS(SELECT 1 From #REPLENISHMENT WHERE LOT =  @c_Fromlot AND  
                                       FromLOC = @c_FromLoc AND ID = @c_Fromid)  
                        BEGIN  
                           INSERT #REPLENISHMENT (  
                           StorerKey, SKU,      FromLOC,  
                           ToLOC,     Lot,      Id,  
                           Qty,       UOM,      PackKey,  
                           Priority,  QtyMoved, QtyInPickLOC)  
                           VALUES (  
                           @c_CurrentStorer,  @c_CurrentSKU, @c_FromLoc,  
                           @c_CurrentLoc,     @c_Fromlot,    @c_Fromid,  
                           @n_FromQty,        @c_UOM,        @c_Packkey,  
                           @c_CurrentPriority,0,             0)  
                        END   
                     END  
                     SELECT @n_NumberOfRecs = @n_NumberOfRecs + 1  
  
                     IF @b_debug = 1  
                     BEGIN  
                        SELECT 'INSERTED : ' as Title, @c_CurrentSKU ' SKU', @c_Fromlot 'LOT',  @c_CurrentLoc 'LOC', @c_Fromid 'ID',   
                               @n_FromQty 'Qty'  
                     END   
                     
                     IF @n_QtyOverAllocated <= 0 AND ISNULL(@c_LastReplenLoc,'') = ''
                        SET @c_LastReplenLoc = @c_FromLoc --only replen 1 loc
                        --GOTO FIND_NEXT_SKU --only replen 1 loc                        
                     
                     IF @n_QtyOverAllocated <= 0 AND @n_Priority = 1 
                           GOTO FIND_NEXT_LOT                                                    
                                
                  END -- if From Qty > 0  
                  IF @b_debug = 1  
                  BEGIN  
                     select @c_CurrentSKU ' SKU', @c_CurrentLoc 'LOC', @n_CurrentFullCase 'full case', @n_CurrentSeverity 'severity'  
                     select @n_RemainingQty '@n_RemainingQty', @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU, @c_Fromlot 'From lot', @c_Fromid  
                  END  
                  IF ISNULL(RTRIM(@c_FromId), '') = ''  
                  BEGIN  
                     BREAK  
                  END  
               END -- SCAN LOT for ID  
  
               FIND_NEXT_LOC: -- SOS#129030  
               FETCH NEXT FROM LOC_CUR INTO @c_FromLoc   
            END -- SCAN LOT for LOC    

            FIND_NEXT_LOT:           
            CLOSE LOC_CUR  
            DEALLOCATE LOC_CUR   

            FETCH NEXT From LOT_CUR INTO @n_Priority, @c_FromLot, @n_QtyOverAllocated, @d_CurrLottable04, @d_CurrLottable05  
         END -- LOT   

         FIND_NEXT_SKU:
         IF (SELECT CURSOR_STATUS('local','LOC_CUR')) >= -1  
         BEGIN
            IF (SELECT CURSOR_STATUS('local','LOC_CUR')) > -1
            BEGIN
              CLOSE LOC_CUR
            END
            DEALLOCATE LOC_CUR
         END
         
         CLOSE LOT_CUR   
         DEALLOCATE LOT_CUR            
         DROP TABLE #TMP_OVERALLOC  
      END -- FOR SKU  
   END   
 
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      /* Update the column QtyInPickLOC in the Replenishment Table */  
      IF @n_continue = 1 or @n_continue = 2  
      BEGIN  
         UPDATE #REPLENISHMENT SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked  
         From SKUxLOC (NOLOCK)  
         WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey AND  
         #REPLENISHMENT.SKU = SKUxLOC.SKU AND  
         #REPLENISHMENT.toLOC = SKUxLOC.LOC  
      END  
   END  
   /* Insert Into Replenishment Table Now */  
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM  
   From #REPLENISHMENT R  
   OPEN CUR1  
   FETCH NEXT From CUR1 INTO @c_FromLoc, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM  
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
         Confirmed)  
         VALUES ('IDS',  
         @c_ReplenishmentKey,  
         @c_CurrentStorer,  
         @c_CurrentSKU,  
         @c_FromLoc,  
         @c_CurrentLoc,  
         @c_FromLot,  
         @c_FromId,  
         @n_FromQty,  
         @c_UOM,  
         @c_PackKey,  
         'N')  
         SELECT @n_err = @@ERROR  
  
      END -- IF @b_success = 1  
      FETCH NEXT From CUR1 INTO @c_FromLoc, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM  
   END -- While  
   CLOSE CUR1   
   DEALLOCATE CUR1  
   -- End Insert Replenishment  
  
--(Wan01) - START
QUIT_SP:
   IF @c_FuncType IN ( 'G' )                                     
   BEGIN
      RETURN
   END
--(Wan01) - END

   IF ( @c_Zone02 = 'ALL')  
   BEGIN  
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,  
      SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey  
      ,LA.Lottable04, LA.Lottable02, LA.Lottable03  
      From  REPLENISHMENT R (NOLOCK)   
      JOIN  SKU (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)  
      JOIN  LOC (NOLOCK) ON (LOC.Loc = R.ToLoc)  
      JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
      JOIN LOTATTRIBUTE LA (NOLOCK) ON (R.Lot = LA.Lot) --GOH01  
      WHERE LOC.Facility = @c_Zone01  
      AND   R.Confirmed = 'N'   
      AND  R.StorerKey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                    R.StorerKey ELSE @c_StorerKey END  
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)                                                
      ORDER BY LOC.PutawayZone, R.Priority  
   END  
   ELSE  
   BEGIN  
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,  
      SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey  
      ,LA.Lottable04, LA.Lottable02, LA.Lottable03  
      From  REPLENISHMENT R (NOLOCK)   
      JOIN  SKU (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)  
      JOIN  LOC (NOLOCK) ON (LOC.Loc = R.ToLoc)  
      JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
      JOIN LOTATTRIBUTE LA (NOLOCK) ON (R.Lot = LA.Lot) --GOH01  
      WHERE LOC.putawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)  
      AND LOC.Facility = @c_Zone01  
      AND Confirmed = 'N'  
      AND  R.StorerKey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                    R.StorerKey ELSE @c_StorerKey END 
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)                                                 
      ORDER BY LOC.PutawayZone, R.Priority  
   END  
END  
 

GO