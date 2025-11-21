SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspALIDSE2                                          */
/* Creation Date: 05-Aug-2002                                            */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:                                                              */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: 1.3                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author    Ver. Purposes                                  */
/* 14-Oct-2004	Mohit			     Change cursor type								         */
/* 18-Jul-2005	Loon				   Add Drop Object statement						     */
/* 11-Aug-2005	MaryVong		   Remove SET ANSI WARNINGS which caused     */
/*										         error in DX											         */
/* 26-Mar-2013  TLTING01  1.1  Add Other Parameter default value         */ 
/* 26-Mar-2020  NJOW01    1.2  WMS-12671 TW Conditional filter hostwhcode*/
/*************************************************************************/

CREATE PROC  [dbo].[nspALIDSE2]  -- rename from IDSTW:nspALIDS02
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

   --NJOW01
   DECLARE @c_Storerkey NVARCHAR(15)

   SELECT @c_Storerkey = Storerkey
   FROM LOT (NOLOCK)
   WHERE Lot = @c_Lot       
   
   IF (dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> '')
    	 OR (EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
   					     WHERE CL.Storerkey = @c_Storerkey  
   					     AND CL.Code = 'NOFILTERHWCODE'  
   					     AND CL.Listname = 'PKCODECFG'  
   					     AND CL.Long = 'nspALIDSE2'  
   					     AND ISNULL(CL.Short,'') = 'N'))  --NJOW01
   BEGIN
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
      AND ISNULL(LOC.HostWhCode,'') = @c_HostWHCode
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
      AND ISNULL(LOC.HostWhCode,'') = @c_HostWHCode
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
      AND ISNULL(LOC.HostWhCode,'') = @c_HostWHCode
      ORDER BY Type, LOTxLOCxID.LOC
   END
   ELSE
   BEGIN
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
      ORDER BY Type, LOTxLOCxID.LOC
   END
END


GO