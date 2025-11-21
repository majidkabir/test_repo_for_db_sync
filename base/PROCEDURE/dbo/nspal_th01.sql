SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_TH01                                         */
/* Creation Date: 03-OCT-2013                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: AllocateStrategy : 287462-Sorting by Max Available Qty      */
/*                                                                      */
/* Called By: nspOrderProcessing		                        */
/*                                                                      */
/* PVCS Version: 1.0		                                        */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author Ver. Purposes                                    */
/************************************************************************/

CREATE PROC    [dbo].[nspAL_TH01]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(20) = ''         
AS
BEGIN
   SET NOCOUNT ON 
    
   
DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
WHERE LOTxLOCxID.Lot = @c_lot
AND LOTxLOCxID.Loc = LOC.LOC
AND LOTxLOCxID.ID = ID.ID
AND ID.Status <> 'HOLD'
AND LOC.Locationflag <> 'HOLD'
AND LOC.Locationflag <> 'DAMAGE'
AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
AND LOC.Status <> 'HOLD'
AND LOC.Facility = @c_Facility
ORDER BY 3 DESC, LOTxLOCxID.LOC, LOTxLOCxID.ID
END


GO