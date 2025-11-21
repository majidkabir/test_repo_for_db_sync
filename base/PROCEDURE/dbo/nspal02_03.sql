SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspAL02_03                                         */    
/* Creation Date: 27-Apr-2015                                           */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 336160 - ECOM allocation strategy                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.5                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author  Ver   Purposes                                   */    
/************************************************************************/    
CREATE PROC [dbo].[nspAL02_03]
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
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
      FROM LOTxLOCxID WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC 
      JOIN ID WITH (NOLOCK)  ON LOTxLOCxID.ID = ID.ID 
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
      AND LOC.Status <> 'HOLD'
      AND LOC.Facility = @c_Facility
      AND ID.STATUS <> 'HOLD'
      ORDER BY LOC.LocLevel, QTYAVAILABLE, LOC.LOC 
END

GO