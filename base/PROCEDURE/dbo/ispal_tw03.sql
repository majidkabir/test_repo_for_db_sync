SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispAL_TW03                                        */
/* Creation Date: 19-Feb-2016                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#362833-LOR - Alloction Strategy Change Request          */
/*                          (duplicate from nspALIDSE2)                 */ 
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

CREATE PROC  [dbo].[ispAL_TW03]  
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
    
   

   IF dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> ''
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), 
       CASE WHEN SKUxLOC.Locationtype = 'PICK' THEN '1' 
           WHEN SKUxLOC.Locationtype = 'CASE' THEN '2'
           WHEN SKUxLOC.Locationtype NOT IN ('PICK', 'CASE') THEN '3' END AS  Type
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (Nolock)
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
      AND LOTxLOCxID.Sku = SKUxLOC.Sku
      AND LOTxLOCxID.Loc = SKUxLOC.Loc
      AND LOTXLOCXID.ID = ID.ID
      AND ID.Status <> "HOLD"
     -- AND SKUxLOC.Locationtype = "PICK"
      AND LOC.Locationflag <>"HOLD"
      AND LOC.Locationflag <> "DAMAGE"
      AND LOC.Status <> "HOLD"
      AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
      AND LOC.Facility = @c_Facility
      AND LOC.HostWhCode = @c_HostWHCode
      ORDER BY Type, LOC.Floor DESC,LOTxLOCxID.LOC
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), 
      CASE WHEN SKUxLOC.Locationtype = 'PICK' THEN '1' 
           WHEN SKUxLOC.Locationtype = 'CASE' THEN '2'
           WHEN SKUxLOC.Locationtype NOT IN ('PICK', 'CASE') THEN '3' END AS  Type
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (Nolock)
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
      AND LOTxLOCxID.Sku = SKUxLOC.Sku
      AND LOTxLOCxID.Loc = SKUxLOC.Loc
      AND LOTXLOCXID.ID = ID.ID
      AND ID.Status <> "HOLD"
     -- AND SKUxLOC.Locationtype = "PICK"
      AND LOC.Locationflag <>"HOLD"
      AND LOC.Locationflag <> "DAMAGE"
      AND LOC.Status <> "HOLD"
      AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
      AND LOC.Facility = @c_Facility
      ORDER BY Type, LOC.Floor DESC,LOTxLOCxID.LOC
   END
END


GO