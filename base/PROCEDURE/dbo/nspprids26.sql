SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: nspPRIDS26                                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 18-Apr-2005  June          SOS34091 - Create for IDSSG               */
/*                            Same as nspPRIDS24, except it sort by     */
/*                            Lot04, lot02 & lot05.                     */
/* 09-Sept-2005 June         SOS40620 - include allocate by Full uom    */
/* 13-Sept-2005 June         SOS40699 - bug fixed                       */
/* 18-AUG-2015  YTWan   1.1   SOS#350432 - Project Merlion -            */
/*                            Allocation Strategy (Wan01)               */
/* 17-Jan-2020  Wan02   1.2   Dynamic SQL review, impact SQL cache log  */   
/************************************************************************/
CREATE PROC    [dbo].[nspPRIDS26]
         @c_storerkey    NVARCHAR(15) ,
         @c_sku          NVARCHAR(20) ,
         @c_lot          NVARCHAR(10) ,
         @c_lottable01   NVARCHAR(18) ,
         @c_lottable02   NVARCHAR(18) ,
         @c_lottable03   NVARCHAR(18) ,
         @d_lottable04   datetime ,
         @d_lottable05   datetime ,
         @c_lottable06   NVARCHAR(30) ,  --(Wan01)  
         @c_lottable07   NVARCHAR(30) ,  --(Wan01)  
         @c_lottable08   NVARCHAR(30) ,  --(Wan01)
         @c_lottable09   NVARCHAR(30) ,  --(Wan01)
         @c_lottable10   NVARCHAR(30) ,  --(Wan01)
         @c_lottable11   NVARCHAR(30) ,  --(Wan01)
         @c_lottable12   NVARCHAR(30) ,  --(Wan01)
         @d_lottable13   DATETIME ,      --(Wan01)
         @d_lottable14   DATETIME ,      --(Wan01)   
         @d_lottable15   DATETIME ,      --(Wan01)
         @c_uom          NVARCHAR(10) ,
         @c_facility     NVARCHAR(10)  ,  -- added By Ricky for IDSV5
         @n_uombase        int ,
         @n_qtylefttofulfill int
        ,@c_OtherParms NVARCHAR(200)=''  --(Wan01)
AS
BEGIN
   -- Start : SOS40620
   DECLARE @c_UOMBase NVARCHAR(10)
   IF @n_uombase <= 0 SELECT @n_uombase = 1
   SELECT @c_UOMBase = @n_uombase
 -- End : SOS40620
   
   DECLARE @c_Condition NVARCHAR(4000) --(Wan01) 
         , @c_OrderBy   NVARCHAR(510)  --(Wan01)
   -- Start : SOS24337
   DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int,  
        @c_manual NVARCHAR(1),
        @n_shelflife int,
        @c_sql NVARCHAR(max),
        @c_Lottable04Label NVARCHAR(20) 
   -- End : SOS24337

   DECLARE @c_SQLParms        NVARCHAR(4000) = ''        --(Wan02)  

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
      -- Start : SOS24337  
      SELECT @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, "") 
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey   
      -- End : SOS24337 

      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> "" AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ' AND LOTTABLE01 = @c_Lottable01'
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> "" AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE02 = @c_Lottable02'
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> "" AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE03 = @c_Lottable03'
      END
      -- Start : SOS24337 
--       IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
--       BEGIN
--          SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = '" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "'"
--       END
      -- End : SOS24337 
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE05 = @d_Lottable05'
      END
      
      if @b_debug = 1
         select @c_lot "@c_lot", @c_Lottable02 "@c_Lottable02"

      -- Start : SOS24337 - IDSMY OW - add by June 21.Jun.04
      -- Min Shelf Life Checking
      IF dbo.fnc_RTrim(@c_Lottable04Label) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable04Label) <> "" 
      BEGIN
         IF LEFT(@c_lot,1) = "*"
         BEGIN
--             DECLARE @c_MinShelfLife60Mth NVARCHAR(1)
               SELECT @n_shelflife = CONVERT(int, SUBSTRING(@c_lot, 2, 9))
--             Select @b_success = 0
--             
--             Execute nspGetRight null,                       -- Facility
--                              @c_storerkey,                 -- Storer
--                              null,                          -- Sku
--                              "MinShelfLife60Mth", 
--                              @b_success            OUTPUT, 
--                              @c_MinShelfLife60Mth  OUTPUT, 
--                              @n_err          OUTPUT, 
--                              @c_errmsg       OUTPUT 
--             If @b_success <> 1
--             Begin
--                Select @c_errmsg = "nspPreAllocateOrderProcessing : " + dbo.fnc_RTrim(@c_errmsg)
--             End            
         
--             IF @c_MinShelfLife60Mth = "1" 
--             BEGIN
--                IF @n_shelflife < 61    
--                   SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + "AND Lottable04 >= '"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
--                ELSE
--                   SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND Lottable04 >= '"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
--             END
--             ELSE
--             BEGIN
--                IF @n_shelflife < 13    
--                   SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND Lottable04 >= '"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
--                ELSE
--                   SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND Lottable04 >= '"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
--             END               
               SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND Lottable04 >= DateAdd(DAY, @n_shelflife, getdate())'
         END
         ELSE
         BEGIN
            SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND Lottable04 >= CONVERT(DATETIME, convert(char(12), getdate(), 106))'
         END 
      END 
      -- End : SOS24337 
      
      --(Wan01) - START
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable06 = @c_Lottable06' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable07 = @c_Lottable07' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable08 = @c_Lottable08' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable09 = @c_Lottable09' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable10 = @c_Lottable10' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable11 = @c_Lottable11' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable12 = @c_Lottable12' 
      END  

      IF CONVERT(CHAR(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable13 = @d_Lottable13'
      END

      IF CONVERT(CHAR(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable14 = @d_Lottable14'
      END

      IF CONVERT(CHAR(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable15 = @d_Lottable15'
      END

      --SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 '
      SET @c_OrderBy = ' ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 '
      --(Wan01) - END
            
      SET @c_Condition = @c_Condition + ' ' -- Wan02

      DECLARE @sql NVARCHAR(max)
      SELECT @sql = "DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR "
            + "SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, "
            -- Start : SOS40620
            -- + "QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) "
            + " QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < @n_UOMBase "   
            + "                THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            + "                WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % @n_UOMBase = 0 "  
            + "                THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            + "                ELSE   " +
            + "                      SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            + "                      - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % @n_UOMBase) "  
            + "                END " + 
            -- End : SOS40620
            + "FROM LOT (NOLOCK) "
            + "INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT "
            + "INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC "
            + "INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " 
            + "INNER JOIN ID  (NOLOCK) ON LOTXLOCXID.ID = ID.ID " 
            + "LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) "
            + "                  FROM   PreallocatePickDetail p (NOLOCK), ORDERS (NOLOCK) "
            + "                  WHERE  p.Orderkey = ORDERS.Orderkey "
            + "                  AND    p.Storerkey = @c_storerkey " 
            + "                  AND    p.SKU = @c_sku " 
            + "                  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility "
            + "WHERE LOT.STORERKEY = @c_storerkey "
            + "AND LOT.SKU = @c_sku "
            + "AND LOC.Facility = @c_facility "
            -- Start : SOS40699 
            -- + "AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' AND (LOC.LOCATIONFLAG <> 'HOLD'  OR LOC.LOCATIONFLAG <> 'DAMAGE' ) "
            + "AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' AND LOC.LOCATIONFLAG <> 'HOLD' AND LOC.LOCATIONFLAG <> 'DAMAGE' "
            -- End : SOS40699 
            + @c_Condition    --(Wan01)
            + "GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE01, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE03, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 "
          -- SOS40620
          -- + "HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0 "
           + " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= @n_UOMBase " +
           -- + @c_Condition  --(Wan01)
           + @c_OrderBy
      
      --(Wan02) - START
      --EXEC ( @sql )
      SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                     + ',@c_storerkey  NVARCHAR(15)'
                     + ',@c_SKU        NVARCHAR(20)'
                     + ',@c_Lottable01 NVARCHAR(18)'
                     + ',@c_Lottable02 NVARCHAR(18)'
                     + ',@c_Lottable03 NVARCHAR(18)'
                     + ',@d_lottable04 datetime'
                     + ',@d_lottable05 datetime'
                     + ',@c_Lottable06 NVARCHAR(30)'
                     + ',@c_Lottable07 NVARCHAR(30)'
                     + ',@c_Lottable08 NVARCHAR(30)'
                     + ',@c_Lottable09 NVARCHAR(30)'
                     + ',@c_Lottable10 NVARCHAR(30)'
                     + ',@c_Lottable11 NVARCHAR(30)'
                     + ',@c_Lottable12 NVARCHAR(30)'
                     + ',@d_lottable13 datetime'
                     + ',@d_lottable14 datetime'
                     + ',@d_lottable15 datetime'
                     + ',@n_shelflife  int'
                     + ',@n_UOMBase    int'
      
      EXEC sp_ExecuteSQL @sql, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                        ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                        ,@n_shelflife, @n_UOMBase       
    --(Wan02) - END
          
      IF @b_debug = 1 
      BEGIN
         SELECT @sql
         SELECT "Condition", @c_Condition
      END
   END
END 

GO