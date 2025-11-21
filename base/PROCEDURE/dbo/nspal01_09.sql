SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: nspAL01_09                                            */    
/* Creation Date: 12-01-2011                                               */    
/* Copyright: IDS                                                          */    
/* Written by: Shong                                                       */    
/*                                                                         */    
/* Purpose: If OrderDetail.MinShelfLife > 0, Take from Bulk 1st then       */    
/*          only look for pick location                                    */    
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
/* 2014-03-05   SHONG     1.1    Sort by Qty                               */    
/***************************************************************************/    
CREATE PROC [dbo].[nspAL01_09]    
     @c_lot              NVARCHAR(10)    
   , @c_uom              NVARCHAR(10)    
   , @c_HostWHCode       NVARCHAR(10)    
   , @c_Facility         NVARCHAR(5)    
   , @n_uombase          Int    
   , @n_qtylefttofulfill Int    
   , @c_OtherParms       NVARCHAR(200) = ''    
AS    
BEGIN    
   SET NOCOUNT ON    
    
   DECLARE @b_debug          Int    
         , @nMinShelfLife    Int    
    
   SELECT @b_debug = 0    
    
   -- Get OrderKey and line Number    
   DECLARE @c_OrderKey        NVARCHAR(10)    
         , @c_OrderLineNumber NVARCHAR(5)    
    
   IF ISNULL(RTRIM(@c_OtherParms),'') <> ''    
   BEGIN    
      SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)    
      SELECT @c_OrderLineNumber = SUBSTRING(LTRIM(@c_OtherParms), 11, 5)    
    
      SET @nMinShelfLife = 0     
      SELECT @nMinShelfLife = ISNULL(MinShelfLife,0)    
      FROM OrderDetail (NOLOCK)    
      WHERE OrderKey = @c_OrderKey    
      AND OrderLineNumber = @c_OrderLineNumber     
   END    
    
   IF RTrim(@c_HostWHCode) IS NOT NULL AND RTrim(@c_HostWHCode) <> ''    
   BEGIN    
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR     
      SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,    
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'    
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
      AND LOC.HostWhCode = @c_HostWHCode     
   --AND @nMinShelfLife > 0 --NJOW     
      ORDER BY    
         CASE WHEN @nMinShelfLife > 0 AND SKUxLOC.LocationType NOT IN ('CASE','PICK') THEN 0     
              WHEN @nMinShelfLife = 0 AND SKUxLOC.LocationType IN ('CASE','PICK') THEN 0  --NJOW  
              ELSE 1     
         END,     
         CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) < @n_qtylefttofulfill THEN 1 ELSE 5 END,  
         (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),         
         LOC.LogicalLocation,       
         LOC.LOC    
   END    
   ELSE    
   BEGIN    
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR     
      SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,    
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'    
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
   --AND @nMinShelfLife > 0 --NJOW     
      ORDER BY    
         CASE WHEN @nMinShelfLife > 0 AND SKUxLOC.LocationType NOT IN ('CASE','PICK') THEN 0     
              WHEN @nMinShelfLife = 0 AND SKUxLOC.LocationType IN ('CASE','PICK') THEN 0    
              ELSE 1     
         END,     
         CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) < @n_qtylefttofulfill THEN 1 ELSE 5 END,  
         (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED),   
         LOC.LogicalLocation,       
         LOC.LOC    
   END     
    
END  

GO