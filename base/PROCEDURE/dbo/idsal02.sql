SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: idsAL02                                            */  
/* Creation Date: 19-11-2008                                            */  
/* Copyright: IDS                                                       */  
/* Written by: Vanessa                                                  */  
/*                                                                      */  
/* Purpose: New Allocation Strategy for GOLD SOS117139                  */  
/*                                                                      */  
/* Called By: Exceed Allocate Orders                                    */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 19-11-2008                 Initial Version                           */
/************************************************************************/  
CREATE PROC    [dbo].[idsAL02]
 @c_lot NVARCHAR(10) ,
 @c_uom NVARCHAR(10) ,
 @c_HostWHCode NVARCHAR(10),
 @c_facility NVARCHAR(5),
 @n_uombase int ,
 @n_qtylefttofulfill int
 AS
 BEGIN
   SET NOCOUNT ON 
    DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
       SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
              QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
       FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), LOT(NOLOCK)
       WHERE LOTxLOCxID.Lot = @c_lot
       AND LOTxLOCxID.Loc = LOC.LOC
       AND LOTxLOCxID.ID = ID.ID
       AND LOTxLOCxID.lot = LOT.lot --SOS131215 ANG01 
       AND ID.Status <> "HOLD"
       AND Lot.status <> "HOLD" --SOS131215 ANG01
       AND LOC.Locationflag <> "HOLD"
       AND LOC.Locationflag <> "DAMAGE"
       AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
       AND LOC.Status <> "HOLD"
       and loc.facility = @c_facility	-- wally 4.nov.2002 for facility-base allocation
       AND (LOC.locationtype = 'DOUBLEDEEP' OR LOC.locationtype = 'SELECTIVE' or LOC.locationtype = 'DRIVEIN')
       ORDER BY LOC.locationtype, LOTxLOCxID.LOC
 END


GO