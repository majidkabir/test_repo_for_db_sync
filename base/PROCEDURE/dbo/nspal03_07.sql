SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL03_07                                         */
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

CREATE PROC    [dbo].[nspAL03_07]
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
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' Type
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Id = ID.ID
   AND LOC.Locationflag <>"HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND LOC.Status <> "HOLD"
   AND ID.STATUS <> "HOLD"
   AND LOC.LocationType = 'PICK'
   AND LOC.Facility = @c_Facility
   AND LOC.HostWhCode = @c_HostWHCode
   AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
   UNION
   SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '2' Type
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Id = ID.ID
   AND LOC.Locationflag <>"HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND LOC.Status <> "HOLD"
   AND ID.STATUS <> "HOLD"
   AND LOC.LocationType = 'CASE'
   AND LOC.Facility = @c_Facility
   AND LOC.HostWhCode = @c_HostWHCode
   AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
   UNION
   SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '3' Type
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Id = ID.ID
   AND LOC.Locationflag <>"HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND LOC.Status <> "HOLD"
   AND ID.STATUS <> "HOLD"
   AND LOC.LocationType NOT IN ('PICK', 'CASE')
   AND LOC.Facility = @c_Facility
   AND LOC.HostWhCode = @c_HostWHCode
   AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
   ORDER BY Type, LOTxLOCxID.LOC DESC
END


GO