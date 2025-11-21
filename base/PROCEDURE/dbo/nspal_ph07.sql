SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspAL_PH07                                         */  
/* Creation Date: 13-Aug-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-17650 PH P&G Allocation Strategy                        */  
/*   1. full pallet from bulk then case/pick   1                        */  
/*   2. full case from case,pick               2                        */  
/*   3. loose from pick,case                   6                        */                     
/*                                                                      */                                                    
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver. Purposes                                   */  
/* 16-Nov-2021  NJOW    1.0  DEVOPS combine script                      */
/************************************************************************/  
CREATE PROC [dbo].[nspAL_PH07]   
@c_lot char(10) ,  
@c_uom char(10) ,  
@c_HostWHCode char(10),  
@c_Facility char(5),  
@n_uombase int ,  
@n_qtylefttofulfill int,  
@c_OtherParms VARCHAR(200) = ''           
AS  
BEGIN  
   SET NOCOUNT ON   
     
  DECLARE @c_OrderKey        VARCHAR(10),  
          @c_WaveKey         VARCHAR(10),  
            @c_LoadKey         VARCHAR(10),    
          @c_OrderLineNumber VARCHAR(5),  
          @c_AllowMonkeyPick CHAR(1) = 'N',  
            @c_key1            VARCHAR(10) = '',  
            @c_key2            VARCHAR(10) = '',  
            @c_key3            VARCHAR(10) = ''  
  
                        
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on  
   BEGIN       
        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)   
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)  
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber                   
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave                 
                  
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')=''   
      BEGIN  
         SET @c_LoadKey = LEFT(@c_OtherParms,10)           
              
       IF EXISTS(SELECT 1   
                 FROM ORDERS AS o WITH(NOLOCK)    
                     JOIN LoadplanDetail Lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey   
                 JOIN STORER AS s WITH(NOLOCK) ON o.ConsigneeKey = s.StorerKey  
                 WHERE lpd.LoadKey = @c_LoadKey   
                 AND S.SUSR2 = 'LEFO')  
       BEGIN  
          SET @c_AllowMonkeyPick = 'Y'  
       END      
      END                                  
      ELSE IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W'   
      BEGIN  
       SET @c_WaveKey = LEFT(@c_OtherParms,10)   
       IF EXISTS(SELECT 1   
                 FROM WAVEDETAIL AS w WITH(NOLOCK)  
                 JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = w.OrderKey  
                 JOIN STORER AS s WITH(NOLOCK) ON o.ConsigneeKey = s.StorerKey  
                 WHERE W.WaveKey=@c_WaveKey  
                 AND S.SUSR2 = 'LEFO')  
       BEGIN  
        SET @c_AllowMonkeyPick = 'Y'  
       END  
      END    
    ELSE   
    BEGIN  
         SET @c_OrderKey = LEFT(@c_OtherParms,10)           
         SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)      
              
       IF EXISTS(SELECT 1   
                 FROM ORDERS AS o WITH(NOLOCK)    
                 JOIN STORER AS s WITH(NOLOCK) ON o.ConsigneeKey = s.StorerKey  
                 WHERE o.OrderKey=@c_OrderKey  
                 AND S.SUSR2 = 'LEFO')  
       BEGIN  
        SET @c_AllowMonkeyPick = 'Y'  
       END               
    END     
   END     
     
   IF @c_UOM  = '1'    
   BEGIN  
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'  
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
      AND LOC.Locationtype NOT IN ('PICK','CASE')   
      AND SKUxLOC.LocationType NOT IN ('PICK','CASE')         
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0   
      AND ISNULL(LOC.Hostwhcode,'') = @c_HostWHCode          
      ORDER BY CASE WHEN LOC.LocationType NOT IN('CASE','PICK') THEN 1 WHEN LOC.LocationType = 'CASE' THEN 2 ELSE 3 END, LOC.LogicalLocation, LOC.LOC   	
   END  
   ELSE IF @c_UOM = '2'  
   BEGIN   
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'  
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
      AND ( (SKUxLOC.Locationtype = 'CASE' OR LOC.LocationType = 'CASE') OR @c_AllowMonkeyPick = 'Y')  
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
      AND ISNULL(LOC.Hostwhcode,'') = @c_HostWHCode         
      ORDER BY LOC.LogicalLocation, LOC.LOC   
      --ORDER BY CASE WHEN LOC.LocationType = 'CASE' THEN 1 WHEN LOC.LocationType = 'PICK' THEN 2 ELSE 3 END, LOC.LogicalLocation, LOC.LOC      
   END  
   ELSE IF @c_UOM = '6'  
   BEGIN   
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'  
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
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
      AND LOC.LocationType IN('CASE','PICK')   
      AND ISNULL(LOC.Hostwhcode,'') = @c_HostWHCode      
      ORDER BY CASE WHEN LOC.LocationType = 'PICK' THEN 1 WHEN LOC.LocationType = 'CASE' THEN 2 ELSE 3 END, LOC.LogicalLocation, LOC.LOC      
   END  
   ELSE  
   BEGIN   
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'  
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
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0   
      AND ISNULL(LOC.Hostwhcode,'') = @c_HostWHCode      
      ORDER BY LOC.LogicalLocation, LOC.LOC      
   END  
END  

GO