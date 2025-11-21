SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALSTDF1                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspALSTDF1]
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
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Loc = SKUxLOC.Loc
   AND LOTxLOCxID.Sku = SKUxLOC.Sku
   AND LOTxLOCxID.ID = ID.ID
   AND ID.Status <> "HOLD"
   AND LOC.Locationflag <> "HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND LOC.Status <> "HOLD"
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 --= @n_uombase
   AND LOC.Status <> "HOLD"
   --AND LOC.LocationType <> "IDZ"
   --AND LOC.LocationType <> "FLOW"
   AND LOC.Facility = @c_Facility
   AND SKUxLOC.LocationType NOT IN ("PICK", "CASE", "IDZ", "FLOW")
   ORDER BY LOTxLOCxID.LOC
END


GO