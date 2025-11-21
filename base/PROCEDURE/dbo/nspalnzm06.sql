SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

-- Modified by MaryVong on 27-Jan-2004 (FBR18050-NZMM)
-- Rename from proc nspALSTDF6
CREATE PROC   [dbo].[nspALNZM06]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN
   
   SET NOCOUNT ON
   
   

   DECLARE @b_debug int
   SELECT @b_debug = 0
   
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' Type
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
   AND LOTxLOCxID.Sku = SKUxLOC.Sku
   AND LOTxLOCxID.Loc = SKUxLOC.Loc
   AND SKUxLOC.Locationtype = "PICK"
   AND LOC.Locationflag <>"HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND LOC.Status <> "HOLD"
   AND LOC.Facility = @c_Facility
   AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > @n_uombase
   
   IF @b_debug = 1
   BEGIN
      SELECT 'Result'
      SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' Type
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK)
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
      AND LOTxLOCxID.Sku = SKUxLOC.Sku
      AND LOTxLOCxID.Loc = SKUxLOC.Loc
      AND SKUxLOC.Locationtype = "PICK"
      AND LOC.Locationflag <>"HOLD"
      AND LOC.Locationflag <> "DAMAGE"
      AND LOC.Status <> "HOLD"
      AND LOC.Facility = @c_Facility
      AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > @n_uombase
   END

END

GO