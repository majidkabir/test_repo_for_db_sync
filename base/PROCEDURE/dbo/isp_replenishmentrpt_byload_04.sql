SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_ReplenishmentRpt_ByLoad_04                     */
/* Creation Date: 06-Jun-2016                                           */
/* Copyright: LF                                                        */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: 371006 - New request for Load Plan Replenishment Strategy   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: r_replenishment_by_load04                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 22-AUG-2016  Wan01   1.1   SOS#374511 - [TW] LCT Replenishment Report*/
/*                            + Lottable02                              */
/************************************************************************/
CREATE PROC [dbo].[isp_ReplenishmentRpt_ByLoad_04]
            @cLoadKey           NVARCHAR(10)
           ,@cFromPAZone        NVARCHAR(10) = ''
           ,@cToLoc             NVARCHAR(10) = ''   
           ,@c_cOrderPercentage NVARCHAR(10) = ''         
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF   
 
    DECLARE @c_UOM        NVARCHAR(10), 
            @c_Facility   NVARCHAR(5),
            @c_Storerkey  NVARCHAR(15),
            @c_Sku        NVARCHAR(20),
            @c_Style      NVARCHAR(20),
            @c_Color      NVARCHAR(10),
            @c_FromLot    NVARCHAR(10),
            @c_FromLoc    NVARCHAR(10),
            @c_FromID     NVARCHAR(18),
            @n_FromQty    int,
            @c_ToLoc      NVARCHAR(10),
            @c_Priority   NVARCHAR(5),
            @c_ReplenishmentKey NVARCHAR(10),
            @c_Packkey    NVARCHAR(10),
            @b_success    int,
            @n_err        int,
            @c_errmsg     NVARCHAR(250),
            @n_continue   int,
            @n_starttcnt  int,
            @n_OrderQty   int, --NJOW01
            @n_AvailableQty float, --NJOW01
            @n_OrderPercentage Float --NJOW01
         ,  @c_Lottable02  NVARCHAR(18)   --(Wan01)
           
   DECLARE @REPLENISHMENT TABLE (
           StorerKey      NVARCHAR(15), 
           SKU            NVARCHAR(20), 
           FromLOC        NVARCHAR(10), 
           ToLOC          NVARCHAR(10), 
           Lot            NVARCHAR(10), 
           Id             NVARCHAR(18), 
           Qty            int, 
           QtyMoved       int, 
           QtyInPickLOC   int,
           Priority       NVARCHAR(5), 
           UOM            NVARCHAR(5), 
           PackKey        NVARCHAR(10)
   )
   
   SELECT @n_continue=1, @n_starttcnt = @@TRANCOUNT, @n_err = 0, @c_errmsg = '', @b_success = 1
   
   --NJOW01
   IF ISNUMERIC(@c_cOrderPercentage) = 1
   	  SELECT @n_OrderPercentage = CAST(@c_cOrderPercentage AS Float)
   ELSE
      SELECT @n_OrderPercentage = 0
   
   SELECT TOP 1 @c_facility = facility
   FROM ORDERS (NOLOCK)
   WHERE Loadkey = @cLoadkey

   IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE Facility = @c_Facility AND Loc = @cToLoc)
   BEGIN
       GOTO EXIT_SP
   END

   IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE Facility = @c_Facility AND Putawayzone = @cFromPAZone)
   BEGIN
       GOTO EXIT_SP
   END
    
 DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ORDERS.Storerkey,SKU.Sku,
                   SUM(ORDERDETAIL.OpenQty) AS OrderQty
                  ,Lottable02 = ISNULL(RTRIM(ORDERDETAIL.Lottable02),'')   --(Wan01)                    
            FROM ORDERS (NOLOCK)
            JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
            JOIN SKU (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey
                              AND ORDERDETAIL.Sku = SKU.Sku
            WHERE ORDERS.Loadkey = @cLoadkey
            --AND ORDERS.Facility = @c_Facility
            --AND ORDERS.Storerkey = @c_Storerkey
            --AND SKU.Style = @c_Style
            --AND SKU.Color = @c_Color
            GROUP BY ORDERS.Storerkey,SKU.Sku
                  ,  ISNULL(RTRIM(ORDERDETAIL.Lottable02),'')   --(Wan01) 
            ORDER BY SKU.Sku
          
         OPEN CUR_SKU
         
         FETCH NEXT FROM CUR_SKU INTO  @c_Storerkey,@c_Sku, @n_OrderQty
                                    ,  @c_Lottable02                       --(Wan01)
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
   	
   	  --NJOW01
      SELECT @n_AvailableQty = SUM(LLI.QTY - LLI.QTYPICKED - LLI.QtyAllocated)
      FROM LOTxLOCxID LLI (NOLOCK) 
      JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      JOIN ID (NOLOCK) ON LLI.ID = ID.Id
      JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc        
      JOIN SKU (NOLOCK) ON SL.Storerkey = SKU.Storerkey AND SL.Sku = SKU.Sku   
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey                
      WHERE LLI.Storerkey = @c_Storerkey
      AND SKU.Sku = @c_Sku
    --  AND SKU.Style = @c_Style
     -- AND SKU.Color = @c_Color                         
      AND LOC.Facility = @c_Facility
      AND LOT.Status <> 'HOLD'
      AND LOC.LocationFlag <> 'DAMAGE'
      AND LOC.LocationFlag <> 'HOLD'
      AND LOC.Status <> 'HOLD'
      AND ID.STATUS <> 'HOLD'  
      AND LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated > 0
      AND (SL.LocationType = 'OTHER' OR ISNULL(SL.Locationtype,'')='')        
      AND LLI.QtyExpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
      --AND LLI.LOC = @cToLoc
      AND LOC.Putawayzone = @cFromPAZone
      
      IF @n_AvailableQty = 0
         SET @n_AvailableQty = 1.00
                  
            DECLARE CUR_Replen_Inv2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
                 SELECT LLI.Lot, LLI.Loc, LLI.ID,                                 
                        LLI.QTY - LLI.QTYPICKED - LLI.QtyAllocated,
                        PACK.Packkey, PACK.PackUOM3                                               
                 FROM LOTxLOCxID LLI (NOLOCK) 
                 JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
                 JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                 JOIN ID (NOLOCK) ON LLI.ID = ID.Id
                 JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc        
                 JOIN SKU (NOLOCK) ON SL.Storerkey = SKU.Storerkey AND SL.Sku = SKU.Sku   
                 JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey   
                 JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)  --(Wan01)
                 WHERE LLI.Storerkey = @c_Storerkey
                 AND SKU.Sku = @c_Sku
                 AND LOC.Facility = @c_Facility
                 AND LOT.Status <> 'HOLD'
                 AND LOC.LocationFlag <> 'DAMAGE'
                 AND LOC.LocationFlag <> 'HOLD'
                 AND LOC.Status <> 'HOLD'
                 AND ID.STATUS <> 'HOLD'  
                 AND LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated > 0
                 AND (SL.LocationType = 'OTHER' OR ISNULL(SL.Locationtype,'')='')        
                 AND LLI.QtyExpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
                 --AND LLI.LOC = @cToLoc
                 AND LOC.Putawayzone = @cFromPAZone
                 AND LA.Lottable02 = CASE WHEN @c_Lottable02 = '' THEN LA.Lottable02 ELSE @c_Lottable02 END --(Wan01)
                 ORDER BY LOC.LogicalLocation, LOC.Loc, LLI.ID, LLI.Sku, LLI.Lot 
            
            OPEN CUR_Replen_Inv2
            FETCH NEXT FROM CUR_Replen_Inv2 INTO @c_fromlot, @c_fromloc, @c_fromid, @n_fromqty, @c_packkey, @c_UOM
             
            WHILE @@FETCH_STATUS <> -1 AND @n_OrderQty > 0
            BEGIN
            	
            	 IF @n_FromQty <= @n_OrderQty
            	 BEGIN
            	 	  SELECT @n_OrderQty = @n_OrderQty - @n_FromQty
            	 END 
            	 ELSE
            	 BEGIN
            	 	  SELECT @n_FromQty = @n_OrderQty
            	 	  SELECT @n_OrderQty = 0
            	 END            	 
            	 
               INSERT @REPLENISHMENT (
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
                      @c_Storerkey,
                      @c_Sku,
                      @c_FromLoc,
                      @cToLoc,
                      @c_fromlot,
                      @c_fromid,
                      @n_FromQty,
                      @c_UOM,
                      @c_Packkey,
                      '99999',
                      0,0)
            FETCH NEXT FROM CUR_Replen_Inv2 INTO @c_fromlot, @c_fromloc, @c_fromid, @n_fromqty, @c_packkey, @c_UOM
            END --Loop inventory of current sku 
            CLOSE CUR_Replen_Inv2
            DEALLOCATE CUR_Replen_Inv2         	
         	
            FETCH NEXT FROM CUR_SKU INTO  @c_Storerkey,@c_Sku, @n_OrderQty
                                        , @c_Lottable02                       --(Wan01)
         END --Loop sku of current sytle and color    	      	 
         CLOSE CUR_SKU
         DEALLOCATE CUR_SKU
         --NJOW01 End

     
   UPDATE @REPLENISHMENT 
   SET  QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked 
   FROM @REPLENISHMENT RP 
   JOIN SKUxLOC (NOLOCK) ON (RP.StorerKey = SKUxLOC.StorerKey AND
                             RP.SKU = SKUxLOC.SKU AND
                              RP.toLOC = SKUxLOC.LOC)

   IF (SELECT COUNT(*) FROM @REPLENISHMENT) > 0 
   BEGIN
      DELETE REPLENISHMENT WHERE Loadkey = @cLoadKey
   END
      
   DECLARE CUR_Replen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM
   FROM   @REPLENISHMENT R
   OPEN CUR_Replen

   FETCH NEXT FROM CUR_Replen INTO @c_FromLoc, @c_FromID, @c_ToLoc, @c_Sku, @n_FromQty, @c_Storerkey, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
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
               Loadkey)
         VALUES (@cLoadKey,
               @c_ReplenishmentKey,
               @c_StorerKey,
               @c_Sku,
               @c_FromLoc,
               @c_ToLoc,
               @c_FromLot,
               @c_FromId,
               @n_FromQty,
               @c_UOM,
               @c_PackKey,
               'N',
               @cLoadkey)

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63524   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into replenishment table failed. (isp_ReplenishmentRpt_ByLoad_04)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
         END
      END -- IF @b_success = 1
      FETCH NEXT FROM CUR_Replen INTO @c_FromLoc, @c_FromID, @c_ToLoc, @c_Sku, @n_FromQty, @c_Storerkey, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
   END -- While
   
   CLOSE CUR_Replen
   DEALLOCATE CUR_Replen

EXIT_SP:

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ReplenishmentRpt_ByLoad_04'
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

   SELECT DISTINCT 
          R.FromLoc, 
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
          (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) As QtyAvailable, 
          LA.Lottable02, 
          LA.Lottable04, 
          R.Loadkey,
          ORD.Sectionkey, 
          L1.loc, L1.facility  
  FROM REPLENISHMENT R (NOLOCK)
  JOIN LOTXLOCXID LLI (NOLOCK) ON R.Lot = LLI.Lot AND R.FromLoc = LLI.Loc AND R.Id = LLI.Id
   JOIN SKU (NOLOCK) ON R.Storerkey = SKU.Storerkey AND R.Sku = SKU.Sku  
   JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
   JOIN LOC L1 (NOLOCK) ON R.FromLoc = L1.Loc
   JOIN ORDERS ORD (NOLOCK) ON SKU.Storerkey = ORD.Storerkey AND R.Loadkey = ORD.Loadkey     
  WHERE R.confirmed = 'N'
  AND  R.Loadkey = @cLoadKey 
  --(Wan01) - START
  AND  L1.PutawayZone = @cFromPAZone
  AND  R.ToLoc = @cToLoc
  --(Wan01) - END
  ORDER BY R.Lot--L1.PutawayZone, R.FromLoc, R.Sku 
END

GO