SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL03_02                                         */
/* Creation Date: 05-Aug-2002                                           */
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
/* 14-Oct-2004	 Mohit			Change cursor type								*/
/* 18-Jul-2005	 Loon				Add Drop Object statement						*/
/* 11-Aug-2005	 MaryVong		Remove SET ANSI WARNINGS which caused     */
/*										error in DX											*/
/*                                                                      */
/************************************************************************/

CREATE PROC    [dbo].[nspAL03_02]
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
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' Type
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (Nolock)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
   AND LOTxLOCxID.Sku = SKUxLOC.Sku
   AND LOTxLOCxID.Loc = SKUxLOC.Loc
   AND LOTXLOCXID.ID = ID.ID
   AND ID.Status <> "HOLD"
   AND SKUxLOC.Locationtype = "PICK"
   AND LOC.Locationflag <>"HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND LOC.Status <> "HOLD"
   AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
   AND LOC.Facility = @c_Facility
   AND LOC.HostWhCode = @c_HostWHCode
   UNION
   SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '2' Type
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
   AND LOTxLOCxID.Sku = SKUxLOC.Sku
   AND LOTxLOCxID.Loc = SKUxLOC.Loc
   AND LOTXLOCXID.ID = ID.ID
   AND ID.Status <> "HOLD"
   AND SKUxLOC.Locationtype = "CASE"
   AND LOC.Locationflag <>"HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND LOC.Status <> "HOLD"
   AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
   AND LOC.Facility = @c_Facility
   AND LOC.HostWhCode = @c_HostWHCode
   UNION
   SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '3' Type
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
   AND LOTxLOCxID.Sku = SKUxLOC.Sku
   AND LOTxLOCxID.Loc = SKUxLOC.Loc
   AND LOTXLOCXID.ID = ID.ID
   AND ID.Status <> "HOLD"
   AND SKUxLOC.Locationtype NOT IN ('PICK', 'CASE')
   AND LOC.Locationflag <>"HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND LOC.Status <> "HOLD"
   AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
   AND LOC.Facility = @c_Facility
   AND LOC.HostWhCode = @c_HostWHCode
   ORDER BY Type, LOTxLOCxID.LOC DESC
END


GO