SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nspPR_SG02                                         */
/* Creation Date: 14-Mar-2016                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  365921-SG-IDSMED FIFO Pre-allocation Strategy.             */
/*           Allocate first by Lotttable10 'RMA'                        */                 
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/*                                                                      */
/* Called By: Allocation                                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */ 
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspPR_SG02]
         @c_storerkey NVARCHAR(15) ,
         @c_sku NVARCHAR(20) ,
         @c_lot NVARCHAR(10) ,
         @c_lottable01 NVARCHAR(18) ,
         @c_lottable02 NVARCHAR(18) ,
         @c_lottable03 NVARCHAR(18) ,
         @d_lottable04 datetime ,
         @d_lottable05 datetime ,
         @c_lottable06 NVARCHAR(30) ,  
         @c_lottable07 NVARCHAR(30) ,  
         @c_lottable08 NVARCHAR(30) ,  
         @c_lottable09 NVARCHAR(30) ,  
         @c_lottable10 NVARCHAR(30) ,  
         @c_lottable11 NVARCHAR(30) ,  
         @c_lottable12 NVARCHAR(30) ,  
         @d_lottable13 DATETIME ,      
         @d_lottable14 DATETIME ,       
         @d_lottable15 DATETIME ,             
         @c_uom NVARCHAR(10) ,
         @c_facility NVARCHAR(10)  ,  
         @n_uombase int ,
         @n_qtylefttofulfill int
        ,@c_OtherParms NVARCHAR(200)=''
AS
BEGIN

DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int,  
     @c_manual NVARCHAR(1),
     @c_LimitString NVARCHAR(4000), 
     @n_shelflife int,
     @c_sql NVARCHAR(max),
     @c_Lottable04Label NVARCHAR(20) 

DECLARE @c_UOMBase NVARCHAR(10)
IF @n_uombase <= 0 SELECT @n_uombase = 1
SELECT @c_UOMBase = @n_uombase

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
   SELECT @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, '') 
   FROM Sku (nolock), Storer (nolock)
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey   
   AND Sku.Storerkey = Storer.Storerkey

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
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
            ELSE
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
         END
         ELSE
         BEGIN
            IF @n_shelflife < 13    
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
            ELSE
               SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
         END               
      END
      ELSE
      BEGIN
         SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= N'" + convert(char(12), getdate(), 106) + "'"
      END 
   END 

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
  
   DECLARE @sql NVARCHAR(max)
   SELECT @sql = " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " + 
   "SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT , " +
             " QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < " + @c_UOMBase +
            "               THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            "               WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " +
            "               THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            "               ELSE   " +
            "                     SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            "                     - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +
            "               END " + 
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
   @c_LimitString + " " +  
   " AND (LOC.LOCATIONFLAG <> 'HOLD'  OR LOC.LOCATIONFLAG <> 'DAMAGE' ) " + 
   " GROUP BY Lotattribute.Lottable04, LOTATTRIBUTE.lottable05, LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable10 " + 
   " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= " + @c_UOMBase + " " +
   " ORDER BY CASE WHEN ISNULL(LOTATTRIBUTE.Lottable10,'') = 'RMA' THEN 0 ELSE 1 END, LOTATTRIBUTE.lottable05 "
   
   EXEC (@sql)
   
   IF @b_debug = 1
   BEGIN
      SELECT @sql    
   END
END 
END

GO