SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_UHPC                                         */
/* Creation Date: 16-Dec-2010                                           */
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
/* Date         Author  Ver.  Purposes                                  */
/* 16-Dec-2010  NJOW01  1.0   196604-Allocation strategy changes for    */
/*                            PP Depot                                  */
/************************************************************************/
CREATE PROC    [dbo].[nspAL_UHPC]
   @c_lot NVARCHAR(10) ,
   @c_uom NVARCHAR(10) ,
   @c_HostWHCode NVARCHAR(10),
   @c_Facility NVARCHAR(5),
   @n_uombase int ,
   @n_qtylefttofulfill int
AS
BEGIN   
   SET NOCOUNT ON 
   
   DECLARE @c_faciflag NVARCHAR(1)
    
   IF @c_Facility IN ('PR','JB')
      SET @c_faciflag = '1'
   ELSE
      SET @c_faciflag = '0'

   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK) 
   JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
   JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
   JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT) -- added by ang (SOS131215)
   JOIN SKUxLOC (NOLOCK) ON (LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
                             AND LOTxLOCxID.Sku = SKUxLOC.Sku
                             AND LOTxLOCxID.Loc = SKUxLOC.Loc)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOC.Locationflag <> 'HOLD'
   AND LOC.Locationflag <> 'DAMAGE'
   AND LOC.Status <> 'HOLD'
   AND LOC.Facility = @c_Facility
   AND ID.STATUS <> 'HOLD'
   AND LOT.STATUS <> 'HOLD' -- added by ang (SOS131215) 
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 -- Shong 31-Sep-2009
   AND '1' = CASE WHEN SKUxLOC.LocationType NOT IN ('PICK','CASE') THEN
                @c_faciflag
           ELSE '1' END
   ORDER BY CASE WHEN SKUxLOC.LocationType IN ('PICK','CASE') THEN '1' ELSE '2' END, LOC.LOC
END

GO