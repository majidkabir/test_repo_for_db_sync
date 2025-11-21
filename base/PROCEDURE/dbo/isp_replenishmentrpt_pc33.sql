SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ReplenishmentRpt_PC33                             */
/* Creation Date:  15-APR-2021                                             */
/* Copyright: LFL                                                          */
/* Written by:CSCHONG                                                      */
/*                                                                         */
/* Purpose: WMS-16734 [CN] LIJIN_REPLENISHMENT_BYID                        */
/*                                                                         */
/*                                                                         */
/* Called By: r_replenishment_Report_pc33                                  */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_ReplenishmentRpt_PC33]
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
,              @c_ReplGrp          NVARCHAR(30)       
,              @c_Functype         NCHAR(1) = ''      
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue                  INT,
           @b_Success                   INT,
           @n_Err                       INT,
           @c_ErrMsg                    NVARCHAR(255),         
           @c_Replenishmentkey          NVARCHAR(10),
           @c_ReplenishmentGroup        NVARCHAR(10),
           @c_CurrentStorerKey          NVARCHAR(15), 
           @c_CurrentFacility           NVARCHAR(5),
           @c_SKU                       NVARCHAR(20), 
           @c_Loc                       NVARCHAR(10),
           @c_FromLoc                   NVARCHAR(10), 
           @c_FromLot                   NVARCHAR(10),
           @c_FromID                    NVARCHAR(18),
           @n_Qty                       INT, 
           @n_QtyPicked                 INT, 
           @n_QtyAllocated              INT, 
           @n_QtyLocationLimit          INT, 
           @n_QtyLocationMinimum        INT,
           @c_ReplenishmentPriority     NVARCHAR(10),
           @c_Packkey                   NVARCHAR(10),         
           @c_UOM                       NVARCHAR(10),
           @n_CaseCnt                   INT, 
           @n_Pallet                    INT, 
           @c_PickCode                  NVARCHAR(10),
           @c_LocationType              NVARCHAR(10), 
           @c_ReplExclProdNearExpiry    NVARCHAR(10),
           @n_NearExpiryDay             INT,
           @n_ReplenQty                 INT,
           @n_RemainingQty              INT,
           @n_PendingMoveIn             INT,
           @c_LocLocationType           NVARCHAR(10),
           @n_NetQtyExpected            INT,
           @n_QtyExpected               INT,
           @n_QtyExpectedFinal          INT,  --for qtyexpected - pendingmovein
           @c_SortColumn                NVARCHAR(20),
           @n_LLIQty                    INT,
           @c_Priority                  NVARCHAR(5),
           @n_QtyinPickLoc              INT,
           @n_OriginalQty               INT,
           @n_QtyToReplen               INT,
           @b_debug                     NVARCHAR(1)
           
   SET @n_continue = 1

   SET @b_debug = 0

   IF RTRIM(@c_ReplGrp) = '' 
      SET @c_ReplGrp = 'ALL'

   IF @c_FuncType IN ( 'P' )                                     
      GOTO QUIT_SP    
      
   IF @n_continue IN(1,2)
   BEGIN
      CREATE TABLE #LOT_SORT
      (
         LOT           NVARCHAR(10),
         SortColumn    NVARCHAR(20),
         QtyExpected   INT DEFAULT(0),
         PendingMoveIn INT DEFAULT(0)
      )
      
      CREATE TABLE #REPLENISHMENT
      (
         Storerkey     NVARCHAR(15),
         SKU           NVARCHAR(20),
         FromLoc       NVARCHAR(10),
         ToLoc         NVARCHAR(10),
         Lot           NVARCHAR(10),
         ID            NVARCHAR(18),
         Qty           INT,
         QtyMoved      INT,
         QtyInPickLoc  INT,
         Priority      NVARCHAR(10),
         Packkey       NVARCHAR(10),
         UOM           NVARCHAR(10),
         DropId        NVARCHAR(20)
      )
         
      DECLARE Cur_ReplenPickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LOC.Facility, 
                SKUxLOC.StorerKey,
                SKUxLOC.SKU, 
                SKUxLOC.LOC, 
                SKUxLOC.Qty, 
                SKUxLOC.QtyPicked, 
                SKUxLOC.QtyAllocated, 
                SKUxLOC.QtyLocationLimit, 
                SKUxLOC.QtyLocationMinimum, 
                SKUxLOC.ReplenishmentPriority, 
                PACK.CaseCnt, 
                PACK.Pallet, 
                SKU.PickCode, 
                SKUxLOC.LocationType, 
                SC2.Svalue, 
                SUM(ISNULL(LOTXLOCXID.QtyExpected,0)),
                SUM(ISNULL(LOTXLOCXID.PendingMoveIn,0)), 
                SUM(ISNULL(LOTXLOCXID.QtyExpected,0)-ISNULL(LOTXLOCXID.PendingMoveIn,0)),
                LOC.LocationType,
                PACK.Packkey,
                PACK.PACKUOM3
         FROM SKUxLOC (NOLOCK) 
         LEFT JOIN LOTXLOCXID (NOLOCK) ON LOTXLOCXID.Storerkey = SKUxLOC.Storerkey AND LOTXLOCXID.Sku = SKUxLOC.Sku AND LOTXLOCXID.Loc = SKUxLOC.Loc 
         JOIN LOC WITH ( NOLOCK ) ON SKUxLOC.Loc = LOC.Loc 
         JOIN SKU WITH ( NOLOCK ) ON SKU.StorerKey = SKUxLOC.StorerKey AND
                                     SKU.SKU = SKUxLOC.SKU 
         JOIN PACK WITH ( NOLOCK ) ON PACK.PackKey = SKU.PACKKey
         LEFT JOIN V_STORERCONFIG2 SC2 ON SKUXLOC.Storerkey = SC2.Storerkey AND SC2.Configkey = 'REPLEXCLPRODNEAREXPIRY_DAY'  --storerconfig to exclude near expiry stock
         WHERE LOC.FACILITY = @c_Zone01 
         AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')
         AND SKUxLOC.LocationType IN ( 'PICK', 'CASE' ) 
         AND LOC.LocationFlag = 'NONE'  
         AND (LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
              OR @c_zone02 = 'ALL')
         GROUP BY LOC.Facility, SKUxLOC.StorerKey, SKUxLOC.SKU, SKUxLOC.LOC, SKUxLOC.Qty, SKUxLOC.QtyPicked, SKUxLOC.QtyAllocated,
                  SKUxLOC.QtyAllocated, SKUxLOC.QtyLocationLimit, SKUxLOC.QtyLocationMinimum, SKUxLOC.ReplenishmentPriority, PACK.CaseCnt, SKUxLOC.LocationType,         
                  PACK.Pallet, SKU.PickCode, SKU.PickCode, SC2.Svalue, LOC.LocationType, PACK.PackKey, PACK.PackUOM3 
         HAVING (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated) + SUM(ISNULL(LOTXLOCXID.PendingMoveIn,0)) <= SKUxLOC.QtyLocationMinimum  --below mininum   -- ZG01
                   OR (SUM(IIF(ISNULL(LOTXLOCXID.PendingMoveIn,0) < ISNULL(LOTXLOCXID.QtyExpected,0), 1, 0)) > 0   --some lotxlocxid over allocated
                       AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated) <= SKUxLOC.QtyLocationMinimum)    -- ZG01             
         ORDER BY SKUxLOC.ReplenishmentPriority, SKUxLOC.Loc 
         
      OPEN Cur_ReplenPickLoc
      
      FETCH NEXT FROM Cur_ReplenPickLoc INTO @c_CurrentFacility, @c_CurrentStorerkey, @c_SKU, @c_Loc, @n_Qty, @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit,
                                             @n_QtyLocationMinimum, @c_ReplenishmentPriority, @n_CaseCnt, @n_Pallet, @c_PickCode, @c_LocationType, @c_ReplExclProdNearExpiry,
                                             @n_QtyExpected, @n_PendingMoveIn, @n_QtyExpectedFinal, @c_LocLocationType, @c_packkey, @c_UOM 

      IF @@FETCH_STATUS <> -1  AND ISNULL(@c_ReplGrp,'') IN ('ALL','') 
      BEGIN
         EXECUTE nspg_GetKey                                                     
            'REPLENGROUP',                                                       
            9,                                                                   
            @c_ReplenishmentGroup OUTPUT,                                        
            @b_success OUTPUT,                                                   
            @n_err OUTPUT,                                                       
            @c_errmsg OUTPUT                                                     
                                                                                 
         IF @b_success = 1                                                      
            SELECT @c_ReplenishmentGroup = 'T' + @c_ReplenishmentGroup           
      END
      ELSE
         SET @c_ReplenishmentGroup = @c_ReplGrp  

      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN    
          SET @n_ReplenQty = 0
          SET @n_NetQtyExpected = 0
          
          SET @c_PickCode = ''  --disable to pickcode checking
          
         SET @c_Priority = @c_ReplenishmentPriority
                                                                   
         DELETE #LOT_SORT
         
         --Get overallocated lots
            INSERT INTO #LOT_SORT (LOT, SortColumn, QtyExpected, PendingMoveIn)
               SELECT LLI.Lot, '', SUM(LLI.QtyExpected), SUM(LLI.PendingMoveIn)
               FROM LOTxLOCxID LLI WITH (NOLOCK)
               WHERE LLI.StorerKey = @c_CurrentStorerkey
               AND   LLI.SKU = @c_SKU
               AND   LLI.LOC = @c_Loc
               AND   (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn < 0
               GROUP BY LLI.Lot
         
         --Get overallocated qty exclude pendingmovein       
         SELECT @n_NetQtyExpected = SUM(QtyExpected - PendingMoveIn)
         FROM #LOT_SORT
                                   
         --Calculate replenishment qty 
         SET @n_ReplenQty = (@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) - @n_PendingMoveIn
         SET @n_QtyinPickLoc = @n_Qty - @n_QtyPicked

       --IF @c_SKU='62714-WHT8'      
       --Begin               
       -- SELECT @c_SKU '@c_sku', @c_loc '@c_loc', @c_PickCode '@c_PickCode'
       -- SELECT @n_QtyLocationLimit '@n_QtyLocationLimit', @n_Qty '@n_Qty', @n_QtyPicked '@n_QtyPicked',@n_PendingMoveIn '@n_PendingMoveIn'
       -- SELECT @n_ReplenQty '@n_ReplenQty', @n_NetQtyExpected '@n_NetQtyExpected'
       --END

         IF @n_ReplenQty < @n_NetQtyExpected --if multi lots, the pendingmovein qty might apply to diffent lot cuased the replenqty less, so have make sure at least replen overallocate qty.
              SET @n_ReplenQty = @n_NetQtyExpected
         
         IF @n_ReplenQty <= 0  
            GOTO NEXT_PICKLOC
         
         --Retrieve available lots sorting by pickcode or standard sql
            IF LEFT(@c_PickCode,5) = 'nspRP'
            BEGIN
               INSERT INTO #LOT_SORT (LOT, SortColumn)
               EXEC(@c_PickCode + ' ''' + @c_CurrentStorerkey + ''','
                             + ' ''' + @c_SKU + ''','
                             + ' ''' + @c_LOC + ''','
                             + ' ''' + @c_CurrentFacility + ''','
                             + ' ''''' )
            END
            ELSE
            BEGIN
               INSERT INTO #LOT_SORT (LOT, SortColumn)
               SELECT DISTINCT
                      LOTxLOCxID.LOT,
                      CASE WHEN LOTTABLE04 IS NULL THEN '00000000'
                           ELSE CONVERT(CHAR(4), DATEPART(year, LOTTABLE04)) +
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(month, LOTTABLE04)),2) +
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(day, LOTTABLE04)),2)
                      END +
                      CASE WHEN LOTTABLE05 IS NULL THEN '00000000'
                           ELSE CONVERT(NVARCHAR(4), DATEPART(year, LOTTABLE05)) +
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(month, LOTTABLE05)),2) +
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(day, LOTTABLE05)),2)
                      END AS SortColumn
               FROM   LOTxLOCxID WITH ( NOLOCK )
               JOIN   LOC WITH ( NOLOCK ) ON LOTxLOCxID.LOC = LOC.LOC
               JOIN   LOTATTRIBUTE WITH ( NOLOCK ) ON LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
               JOIN   LOT WITH (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT
               JOIN   ID WITH (NOLOCK) ON ID.ID = LOTxLOCxID.ID
               JOIN   SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = LOTxLOCxID.StorerKey
                                               AND SL.SKU = LOTxLOCxID.SKU
                                               AND SL.LOC = LOTxLOCxID.LOC
               WHERE  LOTxLOCxID.StorerKey = @c_CurrentStorerkey 
               AND LOTxLOCxID.SKU = @c_SKU 
               AND LOC.LocationFlag = 'NONE' 
               AND LOC.Facility = @c_CurrentFacility 
               AND LOC.Status = 'OK' 
               AND LOT.Status = 'OK' 
               AND ID.Status = 'OK' 
               AND LOTxLOCxID.LOC <> @c_LOC 
               AND (LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen) > 0 
               AND SL.Locationtype NOT IN('CASE','PICK') 
               AND NOT EXISTS(SELECT 1 FROM #LOT_SORT L WHERE L.LOT = LOTxLOCxID.LOT)
               ORDER BY SortColumn
            END
         
         --remove near expiry lots
         SET @n_NearExpiryDay = 0
            IF ISNULL(@c_ReplExclProdNearExpiry,'0') <> '0' AND ISNUMERIC(@c_ReplExclProdNearExpiry) = 1
            BEGIN
                 SET @n_NearExpiryDay = CONVERT(INT, @c_ReplExclProdNearExpiry) * -1 
                 DELETE #LOT_SORT 
                 FROM #LOT_SORT 
                 JOIN LOTATTRIBUTE LA (NOLOCK) ON #LOT_SORT.Lot = LA.Lot
                 WHERE ISNULL(#LOT_SORT.SortColumn,'') <> ''  --Exclude overallocation lot
                 AND DATEADD(Day, @n_NearExpiryDay, LA.Lottable04) <= GETDATE()
            END

         --retrieve lots to replenish
         --IF @c_SKU='62714-WHT8'      
         --BEGIN 
         -- SELECT '#LOT_SORT',* FROM #LOT_SORT
         -- SELECT @n_ReplenQty '@n_ReplenQty'
         --END

            DECLARE cur_REPLENLOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT L.LOT, L.SortColumn
            FROM #LOT_SORT L
            JOIN LOTATTRIBUTE LA (NOLOCK) ON L.Lot = LA.Lot
            ORDER BY L.SortColumn, L.Lot
         
            OPEN cur_REPLENLOT
         
            FETCH NEXT FROM cur_REPLENLOT INTO @c_FromLot, @c_SortColumn 
                                                                       
         SET @n_RemainingQty = @n_ReplenQty

        --IF @b_debug = '1'
        --BEGIN 
       --IF @c_SKU='62714-WHT8'      
       --Begin   
       --   SELECT @n_RemainingQty '@n_RemainingQty', @n_casecnt '@n_casecnt', @n_ReplenQty '@n_ReplenQty', @n_NetQtyExpected '@n_NetQtyExpected'
       -- END  
            WHILE @@FETCH_STATUS <> -1 AND @n_RemainingQty > 0 AND @n_continue IN(1,2)
            BEGIN         
                 --retrieve bulk locations of the lot to replenish 
               DECLARE CUR_LLI_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                SELECT LLI.LOC,
                       LLI.ID,
                       (LLI.Qty -LLI.QtyAllocated-LLI.QtyPicked-lli.PendingMoveIN)
                FROM LOTxLOCxID LLI WITH (NOLOCK)
                JOIN LOC WITH (NOLOCK) ON LLI.LOC = LOC.Loc
                JOIN ID WITH (NOLOCK) ON LLI.ID = ID.Id
                JOIN SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = LLI.StorerKey AND
                                                 SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC
                WHERE LLI.LOT = @c_FromLot
                AND LOC.LocationFlag = 'NONE' 
                AND LOC.Facility = @c_CurrentFacility
                AND LOC.Status = 'OK' 
                AND ID.Status = 'OK'
                AND SL.Locationtype NOT IN('CASE','PICK') 
                AND (LLI.QTY - LLI.QTYPICKED - LLI.QTYALLOCATED - LLI.QtyReplen) > 0
                --ORDER BY LOC.LocationHandling DESC, LOC.LogicalLocation, LOC.Loc, LLI.Qty
                ORDER  BY LLI.ID,
                       LLI.Qty
         
            OPEN CUR_LLI_REPLEN
            
            FETCH NEXT FROM CUR_LLI_REPLEN INTO  @c_FromLoc, @c_FromID, @n_LLIQty
            
            WHILE @@FETCH_STATUS <> -1 AND @n_RemainingQty > 0 AND @n_continue IN(1,2)
            BEGIN
               --IF @n_Casecnt > @n_RemainingQty  --if less than one case skip replenish
               --BEGIN
               --   SET @n_RemainingQty = 0
               --   BREAK
               --   --GOTO NEXT_STOCK
               --END
                                                                         
                --IF @n_RemainingQty >= @n_LLIQty
                --BEGIN
                --     SET @n_QtyToReplen = @n_LLIQty--FLOOR(@n_LLIQty / (@n_casecnt * 1.00)) * @n_Casecnt --take all available with full case
                --END
                --ELSE
                --BEGIN
                --     SET @n_QtyToReplen = @n_NetQtyExpected--FLOOR(@n_RemainingQty / (@n_casecnt * 1.00)) * @n_Casecnt --take all remaining with full case
                --     --IF @n_QtyToReplen > @n_LLIQty  --if last carton over the stock available, remove one carton
                --       --SET @n_QtyToReplen = @n_QtyToReplen - @n_Casecnt   
                --END        

                SET @n_QtyToReplen = @n_LLIQty
               -- IF @c_SKU='62714-WHT8'      
               -- BEGIN 
               --   SELECT   @n_QtyToReplen '@n_QtyToReplen'                       
               --END

               IF @n_QtyToReplen > 0
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
                  ,  DropID
                  )
                     VALUES
                  (
                     @c_CurrentStorerkey
                  ,  @c_SKU
                  ,  @c_FromLOC
                  ,  @c_Loc
                  ,  @c_FromLot
                  ,  @c_Fromid
                  ,  @n_QtyToReplen
                  ,  @c_UOM
                  ,  @c_Packkey
                  ,  @c_Priority
                  ,  0
                  ,  @n_QtyinPickLoc
                  ,  ''
                  )
                   
                   SET @n_RemainingQty = @n_RemainingQty - @n_QtyToReplen
                END
                
                --NEXT_STOCK:
                
            FETCH NEXT FROM CUR_LLI_REPLEN INTO  @c_FromLoc, @c_FromID, @n_LLIQty
            END
            CLOSE CUR_LLI_REPLEN
            DEALLOCATE CUR_LLI_REPLEN
            
            FETCH NEXT FROM cur_REPLENLOT INTO @c_FromLot, @c_SortColumn           
            END
            CLOSE cur_REPLENLOT
            DEALLOCATE cur_REPLENLOT
            
            NEXT_PICKLOC:          
             
         FETCH NEXT FROM Cur_ReplenPickLoc INTO @c_CurrentFacility, @c_CurrentStorerkey, @c_SKU, @c_Loc, @n_Qty, @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit,
                                                @n_QtyLocationMinimum, @c_ReplenishmentPriority, @n_CaseCnt, @n_Pallet, @c_PickCode, @c_LocationType, @c_ReplExclProdNearExpiry,
                                                @n_QtyExpected, @n_PendingMoveIn, @n_QtyExpectedFinal, @c_LocLocationType, @c_packkey, @c_UOM
      END              
      CLOSE Cur_ReplenPickLoc
      DEALLOCATE Cur_ReplenPickLoc                                                      
   END               

   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_REP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT R.FromLoc ,R.Id ,R.ToLoc ,R.Sku ,SUM(R.Qty) ,R.StorerKey
            ,R.Lot, R.PackKey, R.Priority, R.UOM, SUM(R.Qty) 
      FROM #REPLENISHMENT R
      GROUP BY R.FromLoc, R.Id, R.ToLoc, R.Sku, R.StorerKey
              ,R.Lot, R.PackKey, R.Priority, R.UOM
      ORDER BY R.FromLoc        
      
      OPEN CUR_REP
      
      FETCH NEXT FROM CUR_REP INTO @c_FromLOC, @c_FromID, @c_Loc, @c_SKU, @n_Qty, @c_CurrentStorerkey, 
                                   @c_FromLot, @c_PackKey, @c_Priority, @c_UOM, @n_OriginalQty
                                   
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXECUTE nspg_GetKey
               'REPLENISHKEY'
            ,  10
            ,   @c_ReplenishmentKey  OUTPUT
            ,   @b_success          OUTPUT
            ,   @n_err              OUTPUT
            ,   @c_errmsg           OUTPUT
      
         IF @b_success <> 1
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
            ,  Priority
            ,  Confirmed        
            ,  RefNo   
            )
               VALUES (                               
               @c_ReplenishmentGroup  
            ,  @c_ReplenishmentKey
            ,  @c_CurrentStorerkey
            ,  @c_SKU
            ,  @c_FromLOC
            ,  @c_Loc
            ,  @c_FromLot
            ,  @c_FromId
            ,  @n_Qty
            ,  @c_UOM
            ,  @c_PackKey
            ,  @c_Priority
            ,  'N'
            , 'PC33'  
            )
            
            SET @n_err = @@ERROR
         END 
      
         FETCH NEXT FROM CUR_REP INTO @c_FromLOC, @c_FromID, @c_Loc, @c_SKU, @n_Qty, @c_CurrentStorerkey, 
                                      @c_FromLot, @c_PackKey, @c_Priority, @c_UOM, @n_OriginalQty
      END
      CLOSE CUR_REP
      DEALLOCATE CUR_REP
   END
   
   QUIT_SP:

   IF @c_FuncType IN ( 'G' )                                     
   BEGIN
      RETURN
   END

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
         ,PACK.Pallet
         ,R.OriginalQty
         ,R.ReplenishmentKey
         ,R.ReplenishmentGroup
         ,LOTT.Lottable02
         ,R.EditDate AS PrnDate
   FROM  REPLENISHMENT R WITH (NOLOCK)
   JOIN  SKU             WITH (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
   JOIN  LOC             WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
   JOIN  PACK            WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   JOIN  LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.StorerKey = R.Storerkey AND LOTT.Lot=R.Lot
   WHERE R.ReplenishmentGroup = @c_ReplenishmentGroup 
   AND   LOC.facility = @c_zone01
   AND  (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')
   AND  (LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
   OR  @c_zone02 = 'ALL')
   AND R.Confirmed = 'N'
   AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL') 
   ORDER BY LOC.PutawayZone
         ,  R.FromLoc
         ,  R.Id
         ,  R.Sku
END

GO