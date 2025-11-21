SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Stored Procedure: nspAL00001                                            */      
/* Creation Date: 12-01-2011                                               */      
/* Copyright: IDS                                                          */      
/* Written by: Shong                                                       */      
/*                                                                         */      
/* Purpose: Take from Location having Full Pallet Only                     */      
/*                                                                         */      
/*                                                                         */      
/* Called By: Exceed Allocate Orders                                       */      
/*                                                                         */      
/* PVCS Version: 1.0                                                       */      
/*                                                                         */      
/* Version: 5.4                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author     Ver   Purposes                                  */      
/* 27-Aug-2013  Shong      1.0   SOS#291875 Special Allocation Strategy    */      
/*                               for P&G Project                           */
/***************************************************************************/      
      
CREATE PROC [dbo].[nspAL00001]      
     @c_LOT              NVARCHAR(10)      
   , @c_UOM              NVARCHAR(10)      
   , @c_HostWHCode       NVARCHAR(10)      
   , @c_Facility         NVARCHAR(5)      
   , @n_UOMBASE          Int      
   , @n_QtyLeftToFulfill Int      
   , @c_OtherParms       NVARCHAR(200) = ''      
AS      
BEGIN      
   SET NOCOUNT ON      
      
   DECLARE @b_debug          Int      
         , @nMinShelfLife    INT   
      
   SELECT @b_debug = 0      
      
   -- Get OrderKey and line Number      
   DECLARE @c_OrderKey        NVARCHAR(10)      
         , @c_OrderLineNumber NVARCHAR(5)      
      
   IF ISNULL(RTRIM(@c_OtherParms),'') <> ''      
   BEGIN 
      SET @nMinShelfLife = 0  
      -- 
   END      
   
   SET @c_UOM = '1'
   SET @n_UOMBASE = 0
   SELECT @n_UOMBASE = ISNULL(P.PALLET,0) 
   FROM LOT WITH (NOLOCK)
   JOIN SKU s WITH (NOLOCK) ON s.StorerKey = LOT.StorerKey AND s.Sku = LOT.Sku 
   JOIN PACK p WITH (NOLOCK) ON p.PACKKey = s.PACKKey 
   WHERE LOT.Lot = @c_LOT
   
   --SELECT @n_UOMBASE '@n_UOMBASE', @c_UOM '@c_UOM', @n_QtyLeftToFulfill '@n_QtyLeftToFulfill'
      
   DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR       
   SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,      
          QTYAVAILABLE = CASE   
               WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -    
                             (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE    
                         THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                           - (LOTXLOCXID.QTYPICKED)  )   
               WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -   
                             (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0                            
                  THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                           - (LOTXLOCXID.QTYPICKED)  )   
               ELSE   
                  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )   
                  -  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %    
                  @n_UOMBASE  
              END              
        , 1     
   FROM LOTxLOCxID (NOLOCK)       
   JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)       
   JOIN SKUxLOC (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND       
                          LOTxLOCxID.SKU = SKUxLOC.SKU AND       
                          LOTxLOCxID.Loc = SKUxLOC.LOC)      
   JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)       
   WHERE LOTxLOCxID.Lot = @c_lot      
   AND LOC.Locationflag <> 'HOLD'      
   AND LOC.Locationflag <> 'DAMAGE'      
   AND LOC.Status <> 'HOLD'      
   AND LOC.Facility = @c_Facility      
   AND ID.STATUS <> 'HOLD'  
   AND LOC.HostWhCode = CASE WHEN ISNULL(RTRIM(@c_HostWHCode), '') <> '' THEN @c_HostWHCode ELSE LOC.HostWhCode END        
   AND (( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED) ) = @n_QtyLeftToFulfill   
    OR (CASE WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE    
                         THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )   
            WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0                            
                         THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )   
            ELSE ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )   
                     -  (  (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %    
                    @n_UOMBASE  
         END = @n_UOMBASE AND @n_QtyLeftToFulfill >= @n_UOMBASE) )                               
   ORDER BY   
      ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ),          
      LOC.LogicalLocation,         
      LOC.LOC      

      
END 

GO