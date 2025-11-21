SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nspAL01_7D                                         */  
/* Creation Date:  21-Jul-2008                                          */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Pre Allocation Strategy                                     */  
/*                                                                      */  
/* Called By: Exceed Allocate Orders                                    */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 21-Jul-2008          1.0   Initial Version                           */
/* 25-Mar-2009 ang      1.1   SOS131215: Add in Lot.Status <> "Hold"    */
/* 06-Jul-2012 khlim    1.2   SET ANSI_NULLS OFF                        */     
/************************************************************************/ 
CREATE PROC [dbo].[nspAL01_7D]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN
   SET NOCOUNT ON 
    
   
DECLARE  CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY
FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
FROM LOTxLOCxID (NOLOCK),LOC (NOLOCK),ID (NOLOCK), LOT(NOLOCK)
WHERE LOTxLOCxID.Lot = @c_lot
AND LOTxLOCxID.Loc = LOC.LOC
AND LOTxLOCxID.Id = ID.ID
AND LOTXLOCXID.LOT = LOT.LOT --added by ang (SOS131215)
AND LOC.Locationflag <>"HOLD"
AND LOC.Locationflag <> "DAMAGE"
AND LOC.Status <> "HOLD"
AND LOC.Facility = @c_Facility
AND ID.STATUS <> "HOLD"
AND LOT.STATUS <> "HOLD" --added by ang (SOS131215)
ORDER BY loc.locationtype desc ,  LOC.LOC 
END


GO