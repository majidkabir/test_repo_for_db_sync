SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispAL_TW02                                         */  
/* Creation Date: 19-Feb-2016                                           */
/* Copyright: IDS                                                       */
/* Purpose: SOS#362833-LOR - Alloction Strategy Change Request          */
/*                          (duplicate from nspALSTDE1)                 */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/************************************************************************/  
CREATE PROC  [dbo].[ispAL_TW02]     
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
      
     
  
IF dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> ''  
BEGIN  
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)  
   WHERE LOTxLOCxID.Lot = @c_lot  
   AND LOTxLOCxID.Loc = LOC.LOC  
   AND LOTxLOCxID.Loc = SKUxLOC.Loc  
   AND LOTxLOCxID.Sku = SKUxLOC.Sku  
   AND LOTxLOCxID.ID = ID.ID  
   AND ID.Status <> 'HOLD'  
   AND LOC.Facility = @c_Facility   
   AND LOC.Locationflag <> 'HOLD'  
   AND LOC.Locationflag <> 'DAMAGE'  
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase  
   AND LOC.Status <> 'HOLD'  
   AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')  
   AND LOC.HostWhCode = @c_HostWHCode  
   ORDER BY LOC.Floor DESC,LOTxLOCxID.LOC  
END  
ELSE  
BEGIN  
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)  
   WHERE LOTxLOCxID.Lot = @c_lot  
   AND LOTxLOCxID.Loc = LOC.LOC  
   AND LOTxLOCxID.Loc = SKUxLOC.Loc  
   AND LOTxLOCxID.Sku = SKUxLOC.Sku  
   AND LOTxLOCxID.ID = ID.ID  
   AND ID.Status <> 'HOLD'  
   AND LOC.Facility = @c_Facility   
   AND LOC.Locationflag <> 'HOLD'  
   AND LOC.Locationflag <> 'DAMAGE'  
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase  
   AND LOC.Status <> 'HOLD'  
   AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')  
   ORDER BY LOC.Floor DESC,LOTxLOCxID.LOC  
END  
  
END  

GO