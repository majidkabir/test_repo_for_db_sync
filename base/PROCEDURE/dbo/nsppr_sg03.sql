SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nspPR_SG03                                         */
/* Creation Date: 14-Mar-2016                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  365921-SG-IDSMED FEFO Pre-allocation Strategy.             */
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

CREATE PROC    [dbo].[nspPR_SG03]
         @c_storerkey    NVARCHAR(15) ,
         @c_sku          NVARCHAR(20) ,
         @c_lot          NVARCHAR(10) ,
         @c_lottable01   NVARCHAR(18) ,
         @c_lottable02   NVARCHAR(18) ,
         @c_lottable03   NVARCHAR(18) ,
         @d_lottable04   datetime ,
         @d_lottable05   datetime ,
         @c_lottable06   NVARCHAR(30) , 
         @c_lottable07   NVARCHAR(30) , 
         @c_lottable08   NVARCHAR(30) , 
         @c_lottable09   NVARCHAR(30) , 
         @c_lottable10   NVARCHAR(30) , 
         @c_lottable11   NVARCHAR(30) , 
         @c_lottable12   NVARCHAR(30) , 
         @d_lottable13   DATETIME ,     
         @d_lottable14   DATETIME ,      
         @d_lottable15   DATETIME ,     
         @c_uom          NVARCHAR(10) ,
         @c_facility     NVARCHAR(10)  ,  
         @n_uombase        int ,
         @n_qtylefttofulfill int
        ,@c_OtherParms NVARCHAR(200)=''  
AS
BEGIN

   DECLARE @c_UOMBase NVARCHAR(10)
   IF @n_uombase <= 0 SELECT @n_uombase = 1
   SELECT @c_UOMBase = @n_uombase
   
   DECLARE @c_Condition NVARCHAR(4000) 
         , @c_OrderBy   NVARCHAR(510)  
   DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int,  
        @c_manual NVARCHAR(1),
        @n_shelflife int,
        @c_sql NVARCHAR(max),
        @c_Lottable04Label NVARCHAR(20) 

   SELECT @b_debug = 0

   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)), 1) <> "*" 
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR
         FOR SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,  
                    QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
         FROM  LOT (nolock), LOTATTRIBUTE (nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
         WHERE LOT.LOT = @c_lot
         AND LOT.LOT = LOTATTRIBUTE.LOT  
         AND LOTXLOCXID.Lot = LOT.LOT
         AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
         AND LOTXLOCXID.LOC = LOC.LOC
         AND LOC.Facility = @c_facility
         ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05
   END
   ELSE
   BEGIN
      SELECT @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, "") 
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey   

      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> "" AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ' AND LOTTABLE01 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + ''''
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> "" AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE02 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + ''''
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> "" AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE03 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + ''''
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE05 = N''' + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + ''''
      END
      
      if @b_debug = 1
         select @c_lot "@c_lot", @c_Lottable02 "@c_Lottable02"

      -- Min Shelf Life Checking
      IF dbo.fnc_RTrim(@c_Lottable04Label) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable04Label) <> "" 
      BEGIN
         IF LEFT(@c_lot,1) = "*"
         BEGIN
               SELECT @n_shelflife = CONVERT(int, SUBSTRING(@c_lot, 2, 9))
               SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND Lottable04 >= N'''  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + ''''
         END
         ELSE
         BEGIN
            SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND Lottable04 >= N''' + convert(char(12), getdate(), 106) + ''''
         END 
      END 
      
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

      SET @c_OrderBy = ' ORDER BY CASE WHEN ISNULL(LOTATTRIBUTE.Lottable10,'''') = ''RMA'' THEN 0 ELSE 1 END, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 '
            
      DECLARE @sql NVARCHAR(max)
      SELECT @sql = "DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR "
            + "SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, "
            + " QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < " + @c_UOMBase +
            + "                THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            + "                WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " +
            + "                THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            + "                ELSE   " +
            + "                      SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            + "                      - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +
            + "                END " + 
            + "FROM LOT (NOLOCK) "
            + "INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT "
            + "INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC "
            + "INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " 
            + "INNER JOIN ID  (NOLOCK) ON LOTXLOCXID.ID = ID.ID " 
            + "LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) "
            + "                  FROM   PreallocatePickDetail p (NOLOCK), ORDERS (NOLOCK) "
            + "                  WHERE  p.Orderkey = ORDERS.Orderkey "
            + "                  AND    p.Storerkey = N'" + @c_storerkey + "' " 
            + "                  AND    p.SKU = N'" + @c_sku + "' " 
            + "                  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility "
            + "WHERE LOT.STORERKEY = N'" + @c_storerkey  + "' "
            + "AND LOT.SKU = '" + @c_sku + "' "
            + "AND LOC.Facility = N'" + @c_facility + "' "
            + "AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' AND LOC.LOCATIONFLAG <> 'HOLD' AND LOC.LOCATIONFLAG <> 'DAMAGE' "
            + @c_Condition    
            + "GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE01, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE03, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.Lottable10 "
           + " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= " + @c_UOMBase + " " +
           + @c_OrderBy
      
      EXEC ( @sql )
      
      IF @b_debug = 1 
      BEGIN
         SELECT @sql
         SELECT "Condition", @c_Condition
      END
   END
END 

GO