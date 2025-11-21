SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspALLO2_6                                         */  
/* Creation Date: 05-Aug-2002                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 268806 - SG-L'Oreal New Allocation Strategy                 */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.4                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver. Purposes                                   */  
/************************************************************************/  
  
CREATE PROC [dbo].[nspALLO2_6]   
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
     
  DECLARE @n_PickQtyAvailable INT,  
          @c_OrderKey     NVARCHAR(10),  
          @c_OrderLineNumber NVARCHAR(5),  
          @n_OrderQty INT,  
          @c_storerkey VARCHAR(15),  
          @c_Sku NVARCHAR(20),  
          @n_CurrAllocateQty INT  
  
   SELECT @c_storerkey = Storerkey,   
         @c_Sku = Sku  
  FROM LOT (NOLOCK)  
  WHERE Lot = @c_Lot                 
                        
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on  
   BEGIN          
      SET @c_OrderKey = LEFT(@c_OtherParms,10)           
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)  
        
      SELECT @n_CurrAllocateQty = ISNULL(SUM(PD.Qty),0)       
      FROM PICKDETAIL PD (NOLOCK)  
      JOIN SKUXLOC (NOLOCK) ON PD.Storerkey = SKUXLOC.Storerkey AND PD.Sku = SKUXLOC.Sku  
                            AND PD.Loc = SKUXLOC.Loc  
      WHERE PD.Orderkey = @c_Orderkey        
      AND PD.Sku = @c_Sku  
      AND SKUXLOC.LocationType IN ('PICK','CASE')  
        
      SELECT @n_OrderQty = SUM(OpenQty)   
      FROM ORDERDETAIL(NOLOCK)  
      WHERE Orderkey = @c_Orderkey  
      AND Sku = @c_Sku  
   END    
   ELSE  
   BEGIN        
      SET @n_OrderQty = @n_qtylefttofulfill  
      SET @n_CurrAllocateQty = 0  
   END     
     
   IF @c_uom = '2' --Case  
   BEGIN  
      SELECT @n_PickQtyAvailable = SUM(SKUXLOC.Qty - SKUXLOC.QtyAllocated - SKUXLOC.QtyPicked) + @n_CurrAllocateQty  
      FROM SKUXLOC (NOLOCK)  
      JOIN LOC (NOLOCK) ON SKUXLOC.Loc = LOC.Loc  
      AND SKUXLOC.LocationType IN ('PICK','CASE')  
      AND LOC.Facility = @c_facility  
      AND SKUXLOC.Storerkey = @c_Storerkey  
      AND SKUXLOC.Sku = @c_Sku                                              
  
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
      FROM LOTxLOCxID (NOLOCK)  
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC  
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku  
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc  
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID   
      WHERE LOTxLOCxID.Lot = @c_lot  
      AND LOC.Facility = @c_Facility  
      AND LOC.Locationflag <>'HOLD'  
      AND LOC.Locationflag <> 'DAMAGE'  
      AND LOC.Status <> 'HOLD'  
      AND ID.Status = 'OK'        
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase   
      AND 1 = CASE WHEN @n_PickQtyAvailable >= @n_OrderQty AND SKUXLOC.LocationType IN('PICK','CASE') THEN -- Pick loc enough stk, take cases  
                  1  
             WHEN @n_PickQtyAvailable < @n_OrderQty AND SKUXLOC.LocationType NOT IN('PICK','CASE') THEN  -- Pick loc not enough stk, bulk take cases  
                  1  
       ELSE 0 END                    
      ORDER BY LOC.LogicalLocation, LOC.LOC  
   END  
  
   IF @c_uom = '6' --Each - storerconfig 'ALLOWOVERALLOCATIONS' turn on  
   BEGIN          
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
      FROM LOTxLOCxID (NOLOCK)  
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC  
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku  
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc  
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID   
      WHERE LOTxLOCxID.Lot = @c_lot  
      AND LOC.Facility = @c_Facility  
      AND LOC.Locationflag <>'HOLD'  
      AND LOC.Locationflag <> 'DAMAGE'  
      AND LOC.Status <> 'HOLD'  
      AND ID.Status = 'OK'        
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0   
      AND SKUxLOC.Locationtype IN('PICK','CASE')  
      ORDER BY LOC.LogicalLocation, LOC.LOC      
   END  
END  

GO