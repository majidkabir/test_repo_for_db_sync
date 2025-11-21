SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspPRBMI01                                         */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: Vicky                                                    */  
/*                                                                      */  
/* Purpose: SOS#73138 - PreAllocation Strategy for IDSMY BMI            */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date   Author      Purposes                                          */  
/* 2008-01-25 Shong       Initial Version                               */  
/* 2008-09-08 Leong       SOS#95044 - Remove Sorting by                 */   
/*                        MIN(LOTxLOCxID.QTY)                           */  
/************************************************************************/  
  
CREATE PROC [dbo].[nspPRBMI01]  
   @c_storerkey         CHAR(15) ,  
   @c_sku               CHAR(20) ,  
   @c_lot               CHAR(10) ,  
   @c_lottable01        CHAR(18) ,  
   @c_lottable02        CHAR(18) ,  
   @c_lottable03        CHAR(18) ,  
   @d_lottable04        DATETIME ,  
   @d_lottable05        DATETIME ,  
   @c_uom               CHAR(10) ,  
   @c_facility          CHAR(5),   
   @n_uombase           INT ,  
   @n_qtylefttofulfill  INT  
AS  
BEGIN  
  
   DECLARE @n_StorerMinShelfLife int,  
           @c_Condition char(510),  
           @c_SQLStatement varchar(3999)   
     
   IF (LTRIM(RTRIM(@c_lot)) IS NOT NULL AND LTRIM(RTRIM(@c_lot)) <> '')     
   BEGIN  
      /* Get Storer Minimum Shelf Life */  
        
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)  
      FROM Sku (nolock), Storer (nolock), Lot (nolock)  
      WHERE Lot.Lot = @c_lot  
      AND Lot.Sku = Sku.Sku  
      AND Sku.Storerkey = Storer.Storerkey  
      AND Sku.Facility = @c_facility    
        
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
      FROM LOT (Nolock), Lotattribute (Nolock)  
      WHERE LOT.LOT = @c_lot   
      AND Lot.Lot = Lotattribute.Lot   
      AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate()   
      ORDER BY Lotattribute.Lottable05, Lot.Lot  
  
   END  
   ELSE  
   BEGIN  
      /* Get Storer Minimum Shelf Life */  
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)  
      FROM Sku (nolock), Storer (nolock)  
      WHERE Sku.Sku = @c_sku  
      AND Sku.Storerkey = @c_storerkey     
      AND Sku.Storerkey = Storer.Storerkey  
      AND Sku.Facility = @c_facility    
      
      IF @n_StorerMinShelfLife IS NULL  
         SELECT @n_StorerMinShelfLife = 0  
      
      IF RTRIM(LTRIM(@c_Lottable01)) <> '' AND RTRIM(LTRIM(@c_Lottable01)) IS NOT NULL  
      BEGIN  
         SELECT @c_Condition = " AND LOTTABLE01 = '" + RTRIM(LTRIM(@c_Lottable01)) + "' "  
      END  
      IF RTRIM(LTRIM(@c_Lottable02)) <> '' AND RTRIM(LTRIM(@c_Lottable02)) IS NOT NULL  
      BEGIN  
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOTTABLE02 = '" + RTRIM(LTRIM(@c_Lottable02)) + "' "  
      END  
  
      -- Special For BMI, If Lottable03 not specified in OrderDetail  
      -- Only allocate Lottable03 = BLANK   
      -- Lottable03 = Hold Code  
      IF ISNULL(RTRIM(LTRIM(@c_Lottable03)), '') <> ''  
      BEGIN  
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOTTABLE03 = '" + RTRIM(LTRIM(@c_Lottable03)) + "' "  
      END  
      ELSE   
      BEGIN  
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND (LOTTABLE03 = '' OR LOTTABLE03 IS NULL )"   -- ONG01  
      END  
  
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"  
      BEGIN  
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOTTABLE04 = '" + RTRIM(CONVERT( char(20), @d_Lottable04, 106)) + "' "  
      END  
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"  
      BEGIN  
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOTTABLE05 = '" + RTRIM(CONVERT( char(20), @d_Lottable05, 106)) + "' "  
      END  
     
      IF @n_StorerMinShelfLife > 0   
      BEGIN  
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS CHAR(10)) + ", Lotattribute.Lottable04) > GetDate() "   
      END   
  
      SELECT @c_SQLStatement = " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +  
                               " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +  
                               " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )  " +  
                               " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)     " +   
                               " WHERE LOT.STORERKEY = '" + RTRIM(@c_storerkey) + "' " +  
                               " AND LOT.SKU = '" + RTRIM(@c_SKU) + "' " +  
                               " AND LOT.STATUS = 'OK' " +  
                               " AND LOT.LOT = LOTATTRIBUTE.LOT " +  
                               " AND LOTXLOCXID.Lot = LOT.LOT " +  
                               " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +  
                               " AND LOTXLOCXID.LOC = LOC.LOC " +  
                               " AND LOTxLOCxID.ID = ID.ID " +  
                               " AND ID.STATUS <> 'HOLD' " +    
                               " AND LOC.Status = 'OK' " +   
                               " AND LOC.LocationFlag <> 'HOLD' " +  
                               " AND LOC.LocationFlag <> 'DAMAGE' " +  
                               " AND LOC.Facility = '" + RTRIM(@c_facility) + "' " +   
                               " AND LOTATTRIBUTE.STORERKEY = '" + RTRIM(@c_storerkey) + "' " +  
                               " AND LOTATTRIBUTE.SKU = '" + RTRIM(@c_SKU) + "' " +  
                               RTRIM(@c_Condition)  +   
                               " GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02 " +  
                               " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED)   > 0  " +  
                               " ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02 " -- SOS#95044  
                               --" ORDER BY MIN(LOTxLOCxID.QTY), LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02 "-- SOS#95044  
      EXEC(@c_SQLStatement)  
      -- Print @c_SQLStatement  
   END  
END

GO