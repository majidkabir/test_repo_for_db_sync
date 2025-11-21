SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL02_07                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspAL02_07]
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
FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
    QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK),ID (NOLOCK), LOTAttribute (NOLOCK), SKUxLOC (NOLOCK)
WHERE LOTxLOCxID.Lot = @c_lot
  AND LOTxLOCxID.Loc = LOC.LOC
  AND LOTxLOCxID.Sku = SKUxLOC.Sku
  AND LOTxLOCxID.Loc = SKUxLOC.Loc
  AND LOTxLOCxID.ID = ID.ID
  AND LOC.Facility = @c_Facility
  AND LOC.Locationflag <>"HOLD"
  AND LOC.Locationflag <> "DAMAGE"
  AND LOC.Status <> "HOLD"
  AND ID.STATUS <> "HOLD" 
  AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED > 0
  AND LOTxLOCxID.LOT = LOTAttribute.LOT
  AND SKUxLOC.LocationType NOT IN ("PICK", "CASE")
  AND 1 = ( CASE WHEN Lottable03 <> '0101' AND LOTxLOCxID.StorerKey = 'GL' 
                 THEN 1
                 ELSE 2 
            END )
ORDER BY LOC.LogicalLocation, LOC.LOC
END


GO