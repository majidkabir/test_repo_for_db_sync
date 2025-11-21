SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC  [dbo].[nspALClrP2]
	@c_lot NVARCHAR(10) ,
	@c_uom NVARCHAR(10) ,
	@c_HostWHCode NVARCHAR(10),
	@c_Facility NVARCHAR(5),
	@n_uombase int ,
	@n_qtylefttofulfill int
AS
BEGIN
   SET NOCOUNT ON 
    
   
	DECLARE  CURSOR_CANDIDATES SCROLL CURSOR
	FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
		QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
	FROM LOTxLOCxID (NOLOCK)
        JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
        JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)
        JOIN SKUxLOC WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND
                                       LOTxLOCxID.Sku = SKUxLOC.Sku AND
                                       LOTxLOCxID.Loc = SKUxLOC.Loc)
	WHERE LOTxLOCxID.Lot = @c_lot
	AND ID.Status <> 'HOLD'
	AND LOC.Locationflag <> 'HOLD'
	AND LOC.Locationflag <> 'DAMAGE'
	AND LOC.LocationType <> 'IDZ' 
	AND LOC.LocationType <> 'FLOW'
	AND LOC.Facility = @c_Facility
	AND LOC.Status <> 'HOLD' 
   AND LOC.LOC <> '8A0' AND LOTXLOCXID.LOC <> '8A0'  
--    AND LOC.LOC <> '8KSH01' AND LOTXLOCXID.LOC <> '8KSH01'  
--    AND LOC.LOC <> '8KSH02' AND LOTXLOCXID.LOC <> '8KSH02'  
   AND LOC.LOC <> '8KSH03' AND LOTXLOCXID.LOC <> '8KSH03'  
   AND LOC.LOC <> '8KSH04' AND LOTXLOCXID.LOC <> '8KSH04'  
   AND LOC.LOC NOT LIKE '8HATL%' -- SOS36656
	AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0
	AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE', 'IDZ', 'FLOW')
-- change the order by criteria to obtain location first , then qtyavailable, as required by KO (04 Jan 2002)
   -- Changed by June 17.Jul.03 SOS12446, sort by Logicalloc first
	ORDER BY LOC.LogicalLocation, LOTxLOCxID.LOC, qtyavailable
END

GO