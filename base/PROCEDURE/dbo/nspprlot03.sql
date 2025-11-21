SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPRLot03                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: SOS#73138 - PreAllocation Strategy for IDSMY BMI            */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 2007-05-09  Wanyt          Rename Store Procedure Name to nspPRLot03 */
/* 2007-08-22  ONG01          Lot03 = '' should be filtered             */
/* 18-AUG-2015 YTWan    1.1   SOS#350432 - Project Merlion - Allocation */
/*                            Strategy (Wan01)                          */ 
/************************************************************************/

CREATE PROC [dbo].[nspPRLot03]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_lottable06 NVARCHAR(30) ,  --(Wan01)  
@c_lottable07 NVARCHAR(30) ,  --(Wan01)  
@c_lottable08 NVARCHAR(30) ,  --(Wan01)
@c_lottable09 NVARCHAR(30) ,  --(Wan01)
@c_lottable10 NVARCHAR(30) ,  --(Wan01)
@c_lottable11 NVARCHAR(30) ,  --(Wan01)
@c_lottable12 NVARCHAR(30) ,  --(Wan01)
@d_lottable13 DATETIME ,      --(Wan01)
@d_lottable14 DATETIME ,      --(Wan01)   
@d_lottable15 DATETIME ,      --(Wan01)
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(5), 
@n_uombase int ,
@n_qtylefttofulfill int
,@c_OtherParms NVARCHAR(200)=''--(Wan01)
AS
BEGIN
   SET NOCOUNT ON 
    
   
   DECLARE @n_StorerMinShelfLife int,
           @c_Condition NVARCHAR(4000),      --(Wan01)
           @c_SQLStatement NVARCHAR(3999) 
   
   IF (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) <> '')   
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
   
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) IS NOT NULL
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "' "
      END

      -- Check Lottable03 whether is ''   ONG01
      IF ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)), '') <> ''
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + "' "
      END
      ELSE 
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND (LOTTABLE03 = '' OR LOTTABLE03 IS NULL )"      -- ONG01
      END

      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "' "
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + "' "
      END
      --(Wan01) - START
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable06 = N''' + ISNULL(RTRIM(@c_Lottable06),'') + '''' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable07 = N''' + ISNULL(RTRIM(@c_Lottable07),'') + '''' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable08 = N''' + ISNULL(RTRIM(@c_Lottable08),'') + '''' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable09 = N''' + ISNULL(RTRIM(@c_Lottable09),'') + '''' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable10 = N''' + ISNULL(RTRIM(@c_Lottable10),'') + '''' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable11 = N''' + ISNULL(RTRIM(@c_Lottable11),'') + '''' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable12 = N''' + ISNULL(RTRIM(@c_Lottable12),'') + '''' 
      END  

      IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
      END

      IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
      END

      IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                          + ' AND Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
      END
      --(Wan01) - END
         
      IF @n_StorerMinShelfLife > 0 
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() " 
      END 
   
  
     SELECT @c_SQLStatement =  " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
            " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )  " +
            " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)     " + 
            " WHERE LOT.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "' " +
            " AND LOT.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "' " +
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
            " AND LOC.Facility = N'" + dbo.fnc_RTrim(@c_facility) + "' " + 
            " AND LOTATTRIBUTE.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "' " +
            " AND LOTATTRIBUTE.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "' " +
            dbo.fnc_RTrim(@c_Condition)  + 
            " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED)   > 0  " +
            " ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot " 

      EXEC(@c_SQLStatement)

   END
END

GO