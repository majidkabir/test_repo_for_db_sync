SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

-- Sort By Level and then Qty 
CREATE PROC  [dbo].[nspALLVL02]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) , 
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN 
   SET NOCOUNT ON 
    
   
DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK) -- 11-Oct-2004 YTWan to fix allocate to 'HOLD' ID
WHERE LOTxLOCxID.Lot = @c_lot
AND LOTxLOCxID.Loc = LOC.LOC
AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
AND LOTxLOCxID.Sku = SKUxLOC.Sku
AND LOTxLOCxID.Loc = SKUxLOC.Loc
AND LOC.Facility = @c_Facility 
AND LOC.Locationflag <>'HOLD'
AND LOC.Locationflag <> 'DAMAGE'
AND LOC.Status <> 'HOLD'
AND LOTxLOCxID.ID = ID.ID             -- 11-Oct-2004 YTWan to fix allocate to 'HOLD' ID
AND ID.Status <> 'HOLD'               -- 11-Oct-2004 YTWan to fix allocate to 'HOLD' ID
AND (SKUxLOC.LocationType <> 'CASE'   -- 11-Oct-2004 YTWan to fix allocate to 'HOLD' ID
AND  SKUxLOC.LocationType <> 'PICK')  -- 11-Oct-2004 YTWan to fix allocate to 'HOLD' ID
AND LOC.HostWhCode = @c_HostWHCode    -- 11-Oct-2004 YTWan to fix allocate to 'HOLD' ID
AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 ---- 11-Oct-2004 YTWan to fix allocate to 'HOLD' ID
ORDER BY LOCLevel, (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), LOC.LOC   
END

GO