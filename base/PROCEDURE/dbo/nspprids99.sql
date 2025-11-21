SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRIDS99                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Date         Author        Purposes                                  */
/************************************************************************/
/*********************************************************************  */
/*SOS23375 - Changed by June 20.May.2004, add in extra parm @c_OtherParms*/
/*SOS23382 - Changed by June 21.May.2004, to avoid obtaining QtyAvail from other facility*/
/* 18-AUG-2015  YTWan   1.1   SOS#350432 - Project Merlion -            */
/*                            Allocation Strategy (Wan01)               */ 
/***********************************************************************/

CREATE PROC [dbo].[nspPRIDS99]
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
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200) = NULL
AS
BEGIN
        

   DECLARE @n_StorerMinShelfLife int,
           @c_Condition NVARCHAR(4000) --(Wan01) 
         , @c_OrderBy   NVARCHAR(510)  --(Wan01)

   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey

      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      -- Start - SOS23382
      -- QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
      -- FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
      FROM LOTXLOCXID (NOLOCK)
      INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot
      INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot
      INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
      INNER JOIN ID  (NOLOCK) ON LOTXLOCXID.ID = ID.ID
      LEFT OUTER JOIN (SELECT p.lot, ORDERS.facility, QtyPreallocated = SUM(p.Qty)
      FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)
      WHERE p.Orderkey = ORDERS.Orderkey
      AND   p.Storerkey = dbo.fnc_RTrim(@c_storerkey)
      AND   p.SKU = dbo.fnc_RTrim(@c_sku)
      GROUP BY p.Lot, ORDERS.Facility) p ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility
      -- End - SOS23382
      WHERE LOT.LOT = @c_lot
      -- AND Lot.Lot = Lotattribute.Lot
      -- AND LOTXLOCXID.Lot = LOT.LOT
      -- AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
      -- AND LOTXLOCXID.LOC = LOC.LOC
      -- AND LOTXLOCXID.ID = ID.ID
      AND ID.STATUS = 'OK'
      -- Start - SOS23382
      AND LOC.STATUS = 'OK'
      AND LOT.STATUS = 'OK'
      -- End - SOS23382
      AND LOC.Facility = @c_facility
      AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate()
      -- Start - SOS23382
      GROUP BY Lotattribute.Lottable04, LOT.STORERKEY, LOT.SKU, LOT.LOT
      HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= 0
      -- End - SOS23382
      ORDER BY Lotattribute.Lottable04, Lot.Lot
   END
ELSE
   BEGIN
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey
      AND Sku.Storerkey = Storer.Storerkey

      IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + "' "
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
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable09 = N''' + RTRIM(@c_Lottable09) + '''' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable10 = N''' + RTRIM(@c_Lottable10) + '''' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
      END  

      IF CONVERT(CHAR(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
      END

      IF CONVERT(CHAR(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
      END

      IF CONVERT(CHAR(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
      END

      SELECT @c_Condition = " AND ( DateAdd(Day, " + dbo.fnc_RTrim(CAST(@n_StorerMinShelfLife AS NVARCHAR(10))) + ", Lotattribute.Lottable04) > GetDate() OR Lottable04 IS NULL ) "
      --+ dbo.fnc_RTrim(@c_Condition) + " ORDER BY Lotattribute.Lottable04, LOT.Lot"
      SET @c_OrderBy = ' ORDER BY Lotattribute.Lottable04, LOT.Lot'
      --(Wan01) - END
            
      EXEC (" DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
      " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
      -- Start - SOS23382
      -- " QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) " +
      " QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      -- " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK) " +
      "FROM LOTXLOCXID (NOLOCK) " +
      "INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot " +
      "INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +
      "INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
      "INNER JOIN ID  (NOLOCK) ON LOTXLOCXID.ID = ID.ID " +
      " LEFT OUTER JOIN (SELECT p.lot, ORDERS.facility, QtyPreallocated = SUM(p.Qty) " +
      "                 FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
      "                 WHERE p.Orderkey = ORDERS.Orderkey " +
      "                 AND   p.Storerkey = N'" + @c_storerkey + "' " +
      "                 AND   p.SKU = N'" + @c_sku + "' " +
      "                 GROUP BY p.Lot, ORDERS.Facility) p ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility " +
      -- End - SOS23382
      " WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " +
      " AND LOT.SKU = N'" + @c_SKU + "' " +
      " AND LOT.STATUS = 'OK' " +
      " AND ID.STATUS = 'OK' " +
      " AND LOC.STATUS = 'OK' " + -- SOS23382
      " AND LOC.Facility = N'" + @c_facility + "' " +
      @c_Condition +    --(Wan01)
      -- Start - SOS23382
      --" AND LOT.LOT = LOTATTRIBUTE.LOT " +
      -- " AND LOTXLOCXID.Lot = LOT.LOT " +
      -- " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +
      -- " AND LOTXLOCXID.LOC = LOC.LOC " +
      -- " AND LOTXLOCXID.ID = ID.ID " +
      -- " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 " +
      " GROUP BY Lotattribute.Lottable01, Lotattribute.Lottable02, Lotattribute.Lottable03, Lotattribute.Lottable04, Lotattribute.Lottable05, LOT.STORERKEY, LOT.SKU, LOT.LOT  " +
      "HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= 0 " +
      -- End - SOS23382
      --@c_Condition  ) --(Wan01)
      @c_OrderBy        --(Wan01)
      )
   END
END

GO