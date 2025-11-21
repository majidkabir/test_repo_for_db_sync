SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALClrP4 																				*/
/* Creation Date: 18.Dec.2007                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: Copy from nspALClrPl change the sort sequence for Swire CN  */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC  [dbo].[nspALClrP4]
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
	FROM LOTxLOCxID (NOLOCK)
        JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
        JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)
        JOIN SKUxLOC WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND
                                       LOTxLOCxID.Sku = SKUxLOC.Sku AND
                                       LOTxLOCxID.Loc = SKUxLOC.Loc)
	WHERE LOTxLOCxID.Lot = @c_lot
	AND ID.Status <> 'HOLD'
	AND LOC.Locationflag <> 'HOLD'
	AND LOC.Locationflag <> 'DAMAGE'
	AND LOC.LocationType <> 'IDZ' 
	AND LOC.LocationType <> 'FLOW'
	AND LOC.Facility = @c_Facility
	AND LOC.Status <> 'HOLD'
	AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0
	AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE', 'IDZ', 'FLOW')
	ORDER BY QtyAvailable, LOC.LogicalLocation, LOTxLOCxID.LOC 
END

 

GO