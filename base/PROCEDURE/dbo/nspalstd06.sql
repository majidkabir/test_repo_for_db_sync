SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC    [dbo].[nspALSTD06]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms       NVARCHAR(200) = ''     
AS
BEGIN
   SET NOCOUNT ON 
    
   
DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK)
WHERE LOTxLOCxID.Lot = @c_lot
AND LOTxLOCxID.Loc = LOC.LOC
AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
AND LOTxLOCxID.Sku = SKUxLOC.Sku
AND LOTxLOCxID.Loc = SKUxLOC.Loc
AND SKUxLOC.Locationtype ="PICK"
AND LOC.Locationflag <>"HOLD"
AND LOC.Locationflag <> "DAMAGE"
AND LOC.Status <> "HOLD"
AND LOC.Facility = @c_Facility
-- Changed by June 17.Jul.03 SOS12446, sort by Logicalloc first
ORDER BY  LOC.LogicalLocation, LOC.LOC
END


GO