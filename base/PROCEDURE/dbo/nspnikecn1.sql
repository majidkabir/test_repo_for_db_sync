SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC    [dbo].[nspNIKECN1]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) , 
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN 
/* This strategy is created exclusively for NIKECN use.
The logic behind this is the fact that the same SKU has different picking needs.
Warehouses (facilities NSH02 and NGZ02) do not have PICK faces, only pick from BULK. however, the rest of the warehouses
do require case picks from BULK and Piece from PICK.
*/
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)
WHERE LOTxLOCxID.Lot = @c_lot
AND LOTxLOCxID.Loc = LOC.LOC
AND LOTxLOCxID.Loc = SKUxLOC.Loc
AND LOTxLOCxID.Sku = SKUxLOC.Sku
AND LOTxLOCxID.ID = ID.ID
AND ID.Status <> "HOLD" 
AND LOC.Facility IN ('NGZ02', 'NSH02')
AND LOC.Facility = @c_Facility 
AND LOC.Locationflag <> "HOLD"
AND LOC.Locationflag <> "DAMAGE"
AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
AND LOC.Status <> "HOLD"
AND SKUxLOC.LocationType NOT IN ("PICK", "CASE")
ORDER BY LOTxLOCxID.LOC
END

GO