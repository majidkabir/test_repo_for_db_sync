SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL01_07                                         */
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
/* 31-Sep-2009  Shong         Only Return When Qty Available > 0        */
/* 26-Apr-2015  TLTING01 1.1  Add Other Parameter default value         */ 
/*                                                                      */
/************************************************************************/
CREATE PROC    [dbo].[nspAL01_07]
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
    
   
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK) 
   JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
   JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
   JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT) -- added by ang (SOS131215)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOC.Locationflag <> 'HOLD'
   AND LOC.Locationflag <> 'DAMAGE'
   AND LOC.Status <> 'HOLD'
   AND LOC.Facility = @c_Facility
   AND ID.STATUS <> 'HOLD'
   AND LOT.STATUS <> 'HOLD' -- added by ang (SOS131215) 
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 -- Shong 31-Sep-2009
   ORDER BY LOC.LOC
END

GO