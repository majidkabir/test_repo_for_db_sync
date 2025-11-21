SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspAL_TW08                                          */
/* Creation Date: 15-SEP-2022                                            */
/* Copyright: LFL                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-20755 TW HKL Allocation                                  */
/*                                                                       */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author    Ver. Purposes                                  */
/* 15-SEP-2022  NJOW      1.0  DEVOPS Combine Script                     */
/*************************************************************************/

CREATE PROC  [dbo].[nspAL_TW08] 
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

   DECLARE @c_Storerkey NVARCHAR(15)

   SELECT @c_Storerkey = Storerkey
   FROM LOT (NOLOCK)
   WHERE Lot = @c_Lot

   IF (dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> '')
    	 OR (EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
   					       WHERE CL.Storerkey = @c_Storerkey
   					       AND CL.Code = 'NOFILTERHWCODE'
   					       AND CL.Listname = 'PKCODECFG'
   					       AND CL.Long = 'nspAL_TW08'
   					       AND ISNULL(CL.Short,'') = 'N'))  
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
                QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' 
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTXLOCXID.Loc = LOC.Loc
         JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku AND LOTxLOCxID.Loc = SKUxLOC.Loc
         JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID            
         WHERE LOTxLOCxID.Lot = @c_lot
         AND ID.Status = 'OK'
         AND LOC.Locationflag NOT IN('HOLD','DAMAGE')
         AND LOC.Status = 'OK'
         AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
         AND LOC.Facility = @c_Facility
         AND ISNULL(LOC.HostWhCode,'') = @c_HostWHCode
         ORDER BY CASE WHEN LOC.Loclevel = 1 THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.Loc  
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
                QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' 
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON LOTXLOCXID.Loc = LOC.Loc
         JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku AND LOTxLOCxID.Loc = SKUxLOC.Loc
         JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID            
         WHERE LOTxLOCxID.Lot = @c_lot
         AND ID.Status = 'OK'
         AND LOC.Locationflag NOT IN('HOLD','DAMAGE')
         AND LOC.Status = 'OK'
         AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0
         AND LOC.Facility = @c_Facility
         ORDER BY CASE WHEN LOC.Loclevel = 1 THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.Loc 
   END
END


GO