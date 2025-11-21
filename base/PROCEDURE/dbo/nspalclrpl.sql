SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 2019-06-06 1.1  TLTING01 Performance tuning  - avoid recompile        */  

CREATE PROC  [dbo].[nspALClrPl]
	@c_lot NVARCHAR(10) ,
	@c_uom NVARCHAR(10) ,
	@c_HostWHCode NVARCHAR(10),
	@c_Facility NVARCHAR(5),
	@n_uombase int ,
	@n_qtylefttofulfill int,  
   @c_OtherParms NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON 
    
   
	DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
	FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
		QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
	FROM LOT (NOLOCK)
        JOIN LOTxLOCxID (NOLOCK) ON ( LOTxLOCxID.LOT = LOT.LOT )
        JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
        JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)
        JOIN SKUxLOC WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND
                                       LOTxLOCxID.Sku = SKUxLOC.Sku AND
                                       LOTxLOCxID.Loc = SKUxLOC.Loc)
	WHERE LOT.Lot = @c_lot
	AND ID.Status <> N'HOLD'
	AND LOC.Locationflag <> N'HOLD'
	AND LOC.Locationflag <> N'DAMAGE'
	AND LOC.LocationType <> N'IDZ' 
	AND LOC.LocationType <> N'FLOW'
	AND LOC.Facility = @c_Facility
	AND LOC.Status <> N'HOLD'
	AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0
	AND SKUxLOC.LocationType <> N'PICK'  -- NOT IN ('PICK', 'CASE', 'IDZ', 'FLOW')
	AND SKUxLOC.LocationType <> N'CASE'
	AND SKUxLOC.LocationType <> N'IDZ'
	AND SKUxLOC.LocationType <> N'FLOW'
-- change the order by criteria to obtain location first , then qtyavailable, as required by KO (04 Jan 2002)
   -- Changed by June 17.Jul.03 SOS12446, sort by Logicalloc first
	ORDER BY LOC.LogicalLocation, LOTxLOCxID.LOC, qtyavailable
  OPTION (OPTIMIZE FOR UNKNOWN)
  -- OPTION	(RECOMPILE)
END


GO