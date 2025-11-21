SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_SG04                                         */
/* Creation Date: 21-Jan-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-11774 SG PMI Allocation                                 */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC    [dbo].[nspAL_SG04]
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
    
   IF @c_UOM = '2'
   BEGIN    
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY 
         FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT) 
         WHERE LOTxLOCxID.Lot = @c_lot
         AND LOC.Locationflag <> 'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOC.Facility = @c_Facility
         AND ID.STATUS <> 'HOLD'
         AND LOT.STATUS <> 'HOLD' 
         AND LOC.PickZone = 'PMICASEPZ'
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
         ORDER BY LOC.LOC
   END
   ELSE IF @c_UOM = '3'
   BEGIN    
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
         FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT) 
         WHERE LOTxLOCxID.Lot = @c_lot
         AND LOC.Locationflag <> 'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOC.Facility = @c_Facility
         AND ID.STATUS <> 'HOLD'
         AND LOT.STATUS <> 'HOLD' 
         AND LOC.PickZone = 'PMIPACKPZ'
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
         ORDER BY LOC.LOC
   END
   ELSE IF @c_UOM = '4'
   BEGIN    
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
         FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT) 
         WHERE LOTxLOCxID.Lot = @c_lot
         AND LOC.Locationflag <> 'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOC.Facility = @c_Facility
         AND ID.STATUS <> 'HOLD'
         AND LOT.STATUS <> 'HOLD' 
         AND LOC.PickZone = 'PMICARPZ'
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
         ORDER BY LOC.LOC
   END
   ELSE IF @c_UOM = '6'
   BEGIN    
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
         FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT) 
         WHERE LOTxLOCxID.Lot = @c_lot
         AND LOC.Locationflag <> 'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOC.Facility = @c_Facility
         AND ID.STATUS <> 'HOLD'
         AND LOT.STATUS <> 'HOLD' 
         AND LOC.PickZone = 'PMIAGING'
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
         ORDER BY LOC.LOC
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
         FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT) 
         WHERE LOTxLOCxID.Lot = @c_lot
         AND LOC.Locationflag <> 'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOC.Facility = @c_Facility
         AND ID.STATUS <> 'HOLD'
         AND LOT.STATUS <> 'HOLD' 
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
         ORDER BY LOC.LOC
   END

END

GO