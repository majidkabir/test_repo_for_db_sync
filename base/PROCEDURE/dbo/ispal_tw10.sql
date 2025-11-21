SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispAL_TW10                                         */  
/* Creation Date: 11-May-2017                                           */
/* Copyright: IDS                                                       */
/* Purpose: WMS-1112 TW LOC VIP allocation BY MOMO from none-pick loc   */
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/************************************************************************/  
CREATE PROC  [dbo].[ispAL_TW10]     
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

   DECLARE @c_Orderkey NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_ODUserdefine04 NVARCHAR(18)           
           
   IF LEN(@c_OtherParms) > 0
   BEGIN
      SET @c_OrderKey = LEFT(@c_OtherParms ,10)
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
      
      SELECT @c_ODUserdefine04 = Userdefine04
      FROM ORDERDETAIL(NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND OrderLineNumber = @c_OrderLineNumber            
      
      IF @c_ODUserdefine04 <> "MOMO"     
      BEGIN    
          DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
          SELECT TOP 0 NULL, NULL, 0, NULL    
          
          RETURN
      END
   END           
           
   IF dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> ''  
   BEGIN  
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
      SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN), '1'  
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
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) >= @n_uombase  
      AND LOC.Status <> 'HOLD'  
      AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')  
      AND LOC.LocationType <> 'PICK'
      AND LOC.HostWhCode = @c_HostWHCode  
      ORDER BY LOC.LogicalLocation, LOC.Loc
   END  
   ELSE  
   BEGIN  
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
      SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN), '1'  
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
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) >= @n_uombase  
      AND LOC.Status <> 'HOLD'  
      AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')  
      AND LOC.LocationType <> 'PICK'      
      ORDER BY LOC.LogicalLocation, LOC.Loc
   END       
END  

GO