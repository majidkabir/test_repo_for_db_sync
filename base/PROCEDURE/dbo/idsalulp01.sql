SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[idsALULP01]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), LOT(NOLOCK)
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.ID = ID.ID
      AND LOTXLOCXID.LOT = LOT.LOT  -- SOS131215 ANG01
      AND ID.Status = 'OK'
      AND LOT.STATUS = 'OK'  -- SOS131215 ANG01  
      AND LOC.Facility = @c_Facility
      AND LOC.Locationflag = 'NONE'
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
      AND LOC.Status <> "HOLD"
      AND (LOC.locationtype = 'DRIVEIN' OR LOC.locationtype = 'SELECTIVE')
      ORDER BY loc.hostwhcode, LOC.locationtype, LOTxLOCxID.LOC
END


GO