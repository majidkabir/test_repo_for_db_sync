SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALLEVQ2                                         */
/* Creation Date: 25-Nov-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#196753                                                  */   
/*                                                                      */
/* Called By: Load Plan                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC    [dbo].[nspALLEVQ2]
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
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.ID = ID.ID
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
      AND LOC.Status <> 'HOLD'
      AND LOC.Facility = @c_Facility
      AND ID.STATUS <> 'HOLD'
      AND LOC.Loclevel <> 1
      AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
      AND LOTxLOCxID.SKU = SKUxLOC.SKU
      AND LOTxLOCxID.LOC = SKUxLOC.LOC
      ORDER BY (SKUxLOC.QTY - SKUxLOC.QTYALLOCATED - SKUxLOC.QTYPICKED), LOC.LogicalLocation, LOC.LOC 
      	         
END

GO