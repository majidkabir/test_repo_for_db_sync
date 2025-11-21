SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspPRLO2_6                                         */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 268806 - SG-L'Oreal New Allocation Strategy                 */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver. Purposes                                   */  
/************************************************************************/  
  
CREATE PROC [dbo].[nspPRLO2_6]   
@c_storerkey NVARCHAR(15) ,  
@c_sku NVARCHAR(20) ,  
@c_lot NVARCHAR(10) ,  
@c_lottable01 NVARCHAR(18) ,  
@c_lottable02 NVARCHAR(18) ,  
@c_lottable03 NVARCHAR(18) ,  
@c_lottable04 datetime ,  
@c_lottable05 datetime ,  
@c_uom NVARCHAR(10) ,  
@c_facility NVARCHAR(10)  ,    
@n_uombase int ,  
@n_qtylefttofulfill int,  
@c_OtherParms NVARCHAR(20) = ''           
AS  
BEGIN  
  SET NOCOUNT ON  
     
  DECLARE @n_PickQtyAvailable INT,  
          @c_OrderKey     NVARCHAR(10),  
          @c_OrderLineNumber NVARCHAR(5),  
          @n_OrderQty INT         
              
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Preallocation' is turned on  
   BEGIN          
      SET @c_OrderKey = LEFT(@c_OtherParms,10)           
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)  
        
      SELECT @n_OrderQty = SUM(OpenQty - (QtyAllocated+QtyPicked))  
      FROM ORDERDETAIL(NOLOCK)  
      WHERE Orderkey = @c_Orderkey  
      AND Sku = @c_Sku  
   END    
   ELSE  
   BEGIN  
      SET @n_OrderQty = @n_qtylefttofulfill  
   END  
                                             
   IF ISNULL(@c_lot,'') <> ''  
   BEGIN  
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold)  
      FROM LOT (NOLOCK)  
      JOIN LOTXLOCXID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT  
      JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC  
      WHERE LOC.LocationFlag <> 'DAMAGE' And LOC.LocationFlag <> 'HOLD'  
      AND LOC.Facility = @c_facility  
      AND LOT.LOT = @c_lot  
      ORDER BY LOT.LOT  
   END  
   ELSE  
   BEGIN  
      IF @c_uom = '2' --Case  
      BEGIN  
        --If pick loc qty available > order qty, all cases get from pick loc  
        --If pick loc qty available < order qty, all cases get from bulk loc  
        SELECT @n_PickQtyAvailable = SUM(SKUXLOC.Qty - SKUXLOC.QtyAllocated - SKUXLOC.QtyPicked)  
        FROM SKUXLOC (NOLOCK)  
        JOIN LOC (NOLOCK) ON SKUXLOC.Loc = LOC.Loc  
        AND SKUXLOC.LocationType IN ('PICK','CASE')  
         AND LOC.Facility = @c_facility  
         AND SKUXLOC.Storerkey = @c_Storerkey  
         AND SKUXLOC.Sku = @c_Sku                                              
  
         DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
         SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,   
         QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreAllocated)  
         FROM LOT (NOLOCK)  
         JOIN LOTXLOCXID (NOLOCK) ON  LOTXLOCXID.Lot = LOT.LOT  
         JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
         JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Sku = SKUXLOC.Sku   
                               AND LOTXLOCXID.Loc = SKUXLOC.Loc                
         JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC  
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
         WHERE LOT.STORERKEY = @c_storerkey  
         AND LOT.SKU = @c_sku  
         AND LOT.STATUS = 'OK'  
         AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'   
         AND LOC.LocationFlag <> 'DAMAGE' And LOC.LocationFlag <> 'HOLD'     
         AND LOC.Facility = @c_facility  
         AND 1 = CASE WHEN @n_PickQtyAvailable >= @n_OrderQty AND SKUXLOC.LocationType IN('PICK','CASE') THEN -- Pick loc enough stk, take cases  
                           1  
                      WHEN @n_PickQtyAvailable < @n_OrderQty AND SKUXLOC.LocationType NOT IN('PICK','CASE') THEN  -- Pick loc not enough stk, bulk take cases  
                           1  
            ELSE 0 END                    
         GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05   
         HAVING (SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreAllocated)) >= @n_uombase  
         ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05           
      END  
  
      IF @c_uom = '6' --Each  
      BEGIN  
        --If pick loc qty available > order qty, all loose get from pick loc  
        --If pick loc qty available < order qty, all loose get from pick loc with overallocation  
  
         DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
         SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,   
         QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreAllocated)  
         FROM LOT (NOLOCK)  
         JOIN LOTXLOCXID (NOLOCK) ON  LOTXLOCXID.Lot = LOT.LOT  
         JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
         JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Sku = SKUXLOC.Sku   
                               AND LOTXLOCXID.Loc = SKUXLOC.Loc  
         JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC  
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
         WHERE LOT.STORERKEY = @c_storerkey  
         AND LOT.SKU = @c_sku  
         AND LOT.STATUS = 'OK'  
         AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'   
         AND LOC.LocationFlag <> 'DAMAGE' And LOC.LocationFlag <> 'HOLD'     
         AND LOC.Facility = @c_facility  
         GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05   
         HAVING (SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreAllocated)) > 0  
         ORDER BY MIN(CASE WHEN SKUXLOC.LocationType IN ('PICK','CASE') THEN 1 ELSE 2 END),                 
                  LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05           
      END  
   END  
END  

GO