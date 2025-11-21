SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_PH01                                         */
/* Creation Date: 23-Jan-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-978 PH GCI Allocation Strategy                          */
/*   1. full pallet from bulk             1                             */
/*   2. full case from case,bulk          2                             */
/*   3. loose from pick,case,bulk         6                             */                   
/*                                                                      */                                                  
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/************************************************************************/

CREATE PROC [dbo].[nspAL_PH01] 
@c_lot char(10) ,
@c_uom char(10) ,
@c_HostWHCode char(10),
@c_Facility char(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms VARCHAR(200) = ''         
AS
BEGIN
   SET NOCOUNT ON 
   
	 DECLARE @c_OrderKey     VARCHAR(10),
	         @c_OrderLineNumber VARCHAR(5)
	                     
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)
   END   
   
   IF @c_UOM  = '1'  
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Facility = @c_Facility
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND ID.Status = 'OK'
      AND LOC.Locationtype NOT IN ('PICK','CASE')       
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 
      ORDER BY LOC.LogicalLocation, LOC.LOC   	
   END
   ELSE IF @c_UOM = '2'
   BEGIN 
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Facility = @c_Facility
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND ID.Status = 'OK'
      AND LOC.Locationtype NOT IN ('PICK')       
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 
      ORDER BY CASE WHEN LOC.LocationType = 'CASE' THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.LOC   	
   END
   ELSE IF @c_UOM = '6'
   BEGIN 
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Facility = @c_Facility
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND ID.Status = 'OK'
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 
      ORDER BY CASE WHEN LOC.LocationType = 'PICK' THEN 1 WHEN LOC.LocationType = 'CASE' THEN 2 ELSE 3 END, LOC.LogicalLocation, LOC.LOC   	
   END
   ELSE
   BEGIN 
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Facility = @c_Facility
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND ID.Status = 'OK'
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 
      ORDER BY LOC.LogicalLocation, LOC.LOC   	
   END
END

SET QUOTED_IDENTIFIER OFF

GO