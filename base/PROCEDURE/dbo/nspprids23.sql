SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nspPRIDS23                                         */
/* Creation Date: 21-Jun-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose:  Pre-allocation Strategy                                    */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/*                                                                      */
/* Called By: Exceed                                                    */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/* Copy from nspIDS03 script, include storerconfig 'MinShelfLife60Mth'. */
/* & Modify the script to get QtyAvail from lotxlocxid instead of Lot.  */  
/*                                                                      */ 
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 15.Aug.2005  June          SOS39267 - include Allocate by full UOM   */
/* 18-AUG-2015  YTWan   1.1   SOS#350432 - Project Merlion -            */
/*                            Allocation Strategy (Wan01)               */  
/************************************************************************/

CREATE PROC    [dbo].[nspPRIDS23]
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
         @n_qtylefttofulfill int
        ,@c_OtherParms NVARCHAR(200)=''--(Wan01)
AS
BEGIN

-- Start : SOS24145
DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int,  
     @c_manual NVARCHAR(1),
     @c_LimitString NVARCHAR(4000), --(Wan01) 
     @n_shelflife int,
     @c_sql NVARCHAR(max),
     @c_Lottable04Label NVARCHAR(20) 
-- End : SOS24145

-- Start : SOS39267
DECLARE @c_UOMBase NVARCHAR(10)
IF @n_uombase <= 0 SELECT @n_uombase = 1
SELECT @c_UOMBase = @n_uombase
-- End : SOS39267

SELECT @b_debug = 0

IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_lot)),1) <> '*'
BEGIN
   DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
   QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)   
   FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
   WHERE LOT.LOT = LOTATTRIBUTE.LOT  
   AND LOTXLOCXID.Lot = LOT.LOT
   AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
   AND LOTXLOCXID.LOC = LOC.LOC
   AND LOC.Facility = @c_facility
   AND LOT.LOT = @c_lot
   ORDER BY LOTATTRIBUTE.LOTTABLE05
END
ELSE
BEGIN
   -- Start : SOS24145
   SELECT @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, '') -- SOS24145
   FROM Sku (nolock), Storer (nolock)
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey   
   AND Sku.Storerkey = Storer.Storerkey
   -- End : SOS24145

   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
   BEGIN
      SELECT @c_Limitstring = " AND LOTTABLE01 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + "' "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
   BEGIN
      SELECT @c_Limitstring = dbo.fnc_RTrim(@c_Limitstring) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "' "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
   BEGIN
      SELECT @c_Limitstring = dbo.fnc_RTrim(@c_Limitstring) + " AND LOTTABLE03 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + "' "
   END
   IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_lottable05 IS NOT NULL
   BEGIN
      SELECT @c_Limitstring = dbo.fnc_RTrim(@c_Limitstring) + " AND LOTTABLE05 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + "' "
   END

   -- Start : SOS24145 - IDSMY OW - add by June 21.Jun.04
   -- Min Shelf Life Checking
   IF dbo.fnc_RTrim(@c_Lottable04Label) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable04Label) <> '' 
   BEGIN
      IF LEFT(@c_lot,1) = '*'
      BEGIN
         DECLARE @c_MinShelfLife60Mth NVARCHAR(1)
         SELECT @n_shelflife = CONVERT(int, SUBSTRING(@c_lot, 2, 9))
         Select @b_success = 0
         
         Execute nspGetRight null,                       -- Facility
                          @c_storerkey,                 -- Storer
                          null,                          -- Sku
                          'MinShelfLife60Mth', 
                          @b_success                 OUTPUT, 
                          @c_MinShelfLife60Mth  OUTPUT, 
                          @n_err          OUTPUT, 
                          @c_errmsg       OUTPUT 
         If @b_success <> 1
         Begin
            Select @c_errmsg = 'nspPreAllocateOrderProcessing : ' + dbo.fnc_RTrim(@c_errmsg)
         End            
      
         IF @c_MinShelfLife60Mth = '1' 
         BEGIN
            IF @n_shelflife < 61    
               -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
            ELSE
               -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
         END
         ELSE
         BEGIN
            IF @n_shelflife < 13    
               -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
            ELSE
               -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
         END               
      END
      ELSE
      BEGIN
         -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '" + convert(char(12), getdate(), 106) + "'"
         SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'" + convert(char(12), getdate(), 106) + "'"
      END 
   END 
   -- End : SOS24145 

   --(Wan01) - START
   IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
   END   

   IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
   END   

   IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
   END   

   IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable09 = N''' + RTRIM(@c_Lottable09) + '''' 
   END   

   IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable10 = N''' + RTRIM(@c_Lottable10) + '''' 
   END   

   IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
   END   

   IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
   END  

   IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL 
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
   END

   IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL 
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
   END

   IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL
   BEGIN
      SET @c_LimitString = @c_LimitString + ' AND Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
   END
   --(Wan01) - END
   
   DECLARE @sql NVARCHAR(max)
   SELECT @sql = " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " + 
   "SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT , " +
   -- Start : SOS39267
   -- " QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " + 
             " QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < " + @c_UOMBase +
            "               THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            "               WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " +
            "               THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            "               ELSE   " +
            "                     SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            "                     - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +
            "               END " + 
  -- End : SOS39267
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
   " WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " + 
   " AND LOT.SKU = N'" + @c_sku + "' " + 
   " AND LOT.STATUS = 'OK'" +
   " AND ID.STATUS = 'OK' " +
   " AND LOC.STATUS = 'OK' " +
   " AND LOC.Facility = N'" + @c_facility + "' "  + 
   @c_LimitString + " " +  -- SOS24145
   " AND (LOC.LOCATIONFLAG <> 'HOLD'  OR LOC.LOCATIONFLAG <> 'DAMAGE' ) " +  -- SOS24145 
   " GROUP BY Lotattribute.Lottable04, LOTATTRIBUTE.lottable05, LOT.STORERKEY, LOT.SKU, LOT.LOT  " + 
   -- Start : SOS39267
   -- " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= 0 " +
   " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= " + @c_UOMBase + " " +
   -- End : SOS39267
   " ORDER BY LOTATTRIBUTE.lottable05 "
   
   EXEC (@sql)
   
   IF @b_debug = 1
   BEGIN
      SELECT @sql    
   END
END 
END

GO