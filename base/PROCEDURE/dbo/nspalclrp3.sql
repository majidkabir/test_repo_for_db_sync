SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALClrP3                                         */
/* Creation Date: 29-Nov-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: Created based on nspALClrPl for WTC Indent Process.         */
/*          To allocate stocks with LOC.LocationCategory <> 'SELECTIVE' */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*	19-MAR-2009  AUDREY        SOS131215 : ADDED LOT.Status <> 'HOLD'    */	
/************************************************************************/

CREATE PROC  [dbo].[nspALClrP3]
       @c_lot NVARCHAR(10) ,
       @c_uom NVARCHAR(10) ,
       @c_HostWHCode NVARCHAR(10),
       @c_Facility NVARCHAR(5),
       @n_uombase int ,
       @n_qtylefttofulfill int
AS
BEGIN
   SET NOCOUNT ON 
    
   

   DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
          QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON ( LOTxLOCxID.Loc = LOC.LOC AND LOC.Locationflag <> 'HOLD' AND 
                               LOC.Locationflag <> 'DAMAGE' AND LOC.LocationType <> 'IDZ' AND 
                               LOC.LocationType <> 'FLOW' AND LOC.Status <> 'HOLD' AND 
                               LOC.LocationCategory <> 'SELECTIVE' )
   JOIN ID  WITH (NOLOCK) ON ( LOTxLOCxID.ID = ID.ID AND ID.Status <> 'HOLD' )
   JOIN SKUxLOC WITH (NOLOCK) ON ( LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND 
                                   LOTxLOCxID.Sku = SKUxLOC.Sku AND LOTxLOCxID.Loc = SKUxLOC.Loc ) 
   JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> 'HOLD') --SOS131215
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOC.Facility = @c_Facility
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0
   AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE', 'IDZ', 'FLOW')
   ORDER BY LOC.LogicalLocation, LOTxLOCxID.LOC, qtyavailable
END

GO