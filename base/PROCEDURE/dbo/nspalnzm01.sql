SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

-- Modified by MaryVong on 27-Jan-2004 (FBR18050-NZMM)
-- Copy from proc nspALSTD01
CREATE PROC  [dbo].[nspALNZM01]
   @c_lot NVARCHAR(10) ,
   @c_uom NVARCHAR(10) , 
   @c_HostWHCode NVARCHAR(10),
   @c_Facility NVARCHAR(5),
   @n_uombase int ,
   @n_qtylefttofulfill int
AS
BEGIN 
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
   FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK)
   JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
   JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID
   JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc
                        AND LOTxLOCxID.Sku = SKUxLOC.Sku 
                        AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey 
   WHERE LOTxLOCxID.Lot = @c_lot
   AND ID.Status <> 'HOLD' 
   AND LOC.Facility = @c_Facility 
   AND LOC.Locationflag <> 'HOLD'
   AND LOC.Locationflag <> 'DAMAGE'
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
   AND LOC.Status <> 'HOLD'
   AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')
   ORDER BY LOTxLOCxID.LOC
END

GO