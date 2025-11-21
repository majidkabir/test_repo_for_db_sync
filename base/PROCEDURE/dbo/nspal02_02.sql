SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
CREATE  PROC    [dbo].[nspAL02_02]  
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
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN ), '1'  
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)   
      WHERE LOTxLOCxID.Lot = @c_lot  
      AND LOTxLOCxID.Loc = LOC.LOC  
      AND LOTxLOCxID.ID = ID.ID  
      AND LOC.Locationflag <>'HOLD'  
      AND LOC.Locationflag <> 'DAMAGE'  
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) > 0   
      AND LOC.Status <> 'HOLD'  
      AND LOC.Facility = @c_Facility  
      AND ID.STATUS <> 'HOLD'  
      ORDER BY QTYAVAILABLE, LOC.LOC   
END 

GO