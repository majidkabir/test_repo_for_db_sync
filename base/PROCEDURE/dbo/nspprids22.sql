SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRIDS22                                         */
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
/* Version: 5.4.2                                                       */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */ 
/* 20.May.2004  June          SOS23375 - add in extra parm @c_OtherParms*/
/* 21.May.2004  June          SOS23382 - to avoid obtaining QtyAvail    */   
/*                            from other facility                       */
/* 21.June.2004 June          for IDSMY OW => Copy from nspIDS99 script,*/
/*                            include storerconfig'MinShelfLife60Mth'.  */
/* 18-AUG-2015  YTWan   1.1   SOS#350432 - Project Merlion -            */
/*                            Allocation Strategy (Wan01)               */
/* 24-Jul-2017  TLTING  1.2   Dynamic SQL review, impact SQL cache log  */  
/* 23-Sep-2019  CSCHONG 1.3   WMS-10690 (CS01)                          */
/************************************************************************/

CREATE PROC [dbo].[nspPRIDS22]
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
   SET NOCOUNT ON
   DECLARE @n_StorerMinShelfLife int,
           @c_Condition NVARCHAR(510)      

   -- Add by June 
   IF @n_uombase <= 0 SELECT @n_uombase = 1
   
   -- Start : SOS24145
   DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int,  
        @c_manual NVARCHAR(1),
        @c_LimitString NVARCHAR(4000),    --(Wan01) 
        @n_shelflife int,
        @c_sql NVARCHAR(max),
        @c_Lottable04Label NVARCHAR(20),    
        @c_SQLParm      NVARCHAR(MAX),
        @d_today  datetime 
   -- End : SOS24145

   SELECT @b_debug = 0
   SET @c_SQLParm = ''
   SET @d_today = convert(char(12), getdate(), 106)
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_lot)),1) <> '*'
   BEGIN    
      /* Get Storer Minimum Shelf Life */    
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey
      
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR
      FOR 
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      -- Start - SOS23382
      -- QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      -- QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) 
      QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < @n_UOMBase
                        THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
                        WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % @n_UOMBase = 0
                        THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
                        ELSE
                        SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
                        - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % @n_UOMBase)
                     END
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
      AND LOC.Locationflag = "NONE"
      -- End - SOS23382
      AND LOC.Facility = @c_facility
      AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
      -- Start - SOS23382
      GROUP BY Lotattribute.Lottable04, LOT.STORERKEY, LOT.SKU, LOT.LOT 
      -- HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= 0 
      HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= @n_UOMBase
      -- End - SOS23382
      ORDER BY Lotattribute.Lottable04, Lot.Lot   
   END
   ELSE
   BEGIN
   /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1),
             @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, '') -- SOS24145
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey
   
      IF @n_StorerMinShelfLife IS NULL
         SELECT @n_StorerMinShelfLife = 0

      --(Wan01) - START
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
          SELECT @c_LimitString = " AND LOTTABLE01 = RTrim(LTrim(@c_Lottable01)) "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND LOTTABLE02 = RTrim(LTrim(@c_Lottable02)) "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND LOTTABLE03 = RTrim(LTrim(@c_Lottable03)) "
      END

	 -- SOS24145, OW IDSMY - add by June 21.Jun.04    --(CS01 START)
   
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_lottable04 IS NOT NULL
      BEGIN  
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = @d_Lottable04 "  
      END  
	  /*CS01 End*/

      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_lottable05 IS NOT NULL
      BEGIN
         SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND LOTTABLE05 = @d_Lottable05 "
      END
      
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable06 = RTRIM(@c_Lottable06) ' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable07 = RTRIM(@c_Lottable07) ' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable08 = RTRIM(@c_Lottable08) ' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable09 = RTRIM(@c_Lottable09) ' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable10 = RTRIM(@c_Lottable10) ' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable11 = RTRIM(@c_Lottable11) ' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable12 = RTRIM(@c_Lottable12) ' 
      END  

      IF CONVERT(CHAR(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_lottable13 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable13 = @d_Lottable13 '
      END

      IF CONVERT(CHAR(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_lottable14 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable14 = @d_Lottable14 '
      END

      IF CONVERT(CHAR(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_lottable15 IS NOT NULL
      BEGIN
         SET @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable15 = @d_Lottable15 '
      END
 
      --SELECT @c_Condition = " AND ( DateAdd(Day, " + dbo.fnc_RTrim(CAST(@n_StorerMinShelfLife AS NVARCHAR(10))) + ", Lotattribute.Lottable04) > GetDate() OR Lottable04 IS NULL ) " 
      --       + dbo.fnc_RTrim(@c_Condition) + " ORDER BY Lotattribute.Lottable04, LOT.Lot"
      SET @c_Condition = @c_Condition + ' ORDER BY Lotattribute.Lottable04, LOT.Lot'
      --(Wan01) - END

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
               -- have to divide by 30 to reverse nspPreallocateOrderProcessing computation
               IF (@n_shelflife/30) < 61
                  -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
                  SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= DateAdd(MONTH, @n_shelflife/30, @d_today) "
               ELSE
                  -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
                  SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= DateAdd(DAY, @n_shelflife, @d_today) "
            END
            ELSE
            BEGIN
               IF @n_shelflife < 13    
                  -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '"  + convert(char(12), DateAdd(MONTH, @n_shelflife, getdate()), 106) + "'"
                  SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= DateAdd(MONTH, @n_shelflife, @d_today) "
               ELSE
                  -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '"  + convert(char(12), DateAdd(DAY, @n_shelflife, getdate()), 106) + "'"
                  SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= DateAdd(DAY, @n_shelflife, @d_today) "
            END            
         END
         ELSE
         BEGIN
            -- SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(12),Lottable04, 106) >= '" + convert(char(12), getdate(), 106) + "'"
            SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 >= @d_today "
         END 
      END 
      -- End : SOS24145 

      DECLARE @sql NVARCHAR(max)
      SELECT @sql = " DECLARE  PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
            -- Start - SOS23382
            -- " QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) " + 
            -- " QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " + 
            " QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < @n_uombase " +
            "               THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            "               WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % @n_uombase = 0 " +
            "               THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            "               ELSE   " +
            "                     SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            "                     - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % @n_uombase ) " +
            "               END " + 
            -- " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK) " +
            "FROM LOTXLOCXID (NOLOCK) " +
            "INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot " +
            "INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +
            "INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
            "INNER JOIN ID  (NOLOCK) ON LOTXLOCXID.ID = ID.ID " +
            " LEFT OUTER JOIN (SELECT p.lot, ORDERS.facility, QtyPreallocated = SUM(p.Qty) " +
            "                 FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
            "                 WHERE p.Orderkey = ORDERS.Orderkey " +
            "                 AND   p.Storerkey = @c_storerkey " +
            "                 AND   p.SKU = @c_sku " +
            "                 GROUP BY p.Lot, ORDERS.Facility) p ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility " +
            -- End - SOS23382
            " WHERE LOT.STORERKEY = @c_storerkey " +
            " AND LOT.SKU = @c_SKU " +
            " AND LOT.STATUS = 'OK' " +
            " AND ID.STATUS = 'OK' " +
            " AND LOC.STATUS = 'OK' " + -- SOS23382
            " AND LOC.Facility = @c_facility " +
            @c_LimitString + " " + -- SOS24145 
            " AND LOC.Locationflag = 'NONE' " +  -- SOS24145 
            -- Start - SOS23382
            --" AND LOT.LOT = LOTATTRIBUTE.LOT " +
            -- " AND LOTXLOCXID.Lot = LOT.LOT " +
            -- " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +
            -- " AND LOTXLOCXID.LOC = LOC.LOC " +
            -- " AND LOTXLOCXID.ID = ID.ID " +
            -- " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 " +
            " GROUP BY Lotattribute.Lottable01, Lotattribute.Lottable02, Lotattribute.Lottable03, Lotattribute.Lottable04, Lotattribute.Lottable05, LOT.STORERKEY, LOT.SKU, LOT.LOT  " + 
            -- "HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= 0 " +
            " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= @n_uombase " +
            -- End - SOS23382
            @c_Condition 

      SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                         '@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,     @c_Lottable06 NVARCHAR(30), ' +
                         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' + 
                         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' + 
                         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +
                         '@n_uombase  INT,            @d_today DATETIME,          @n_ShelfLife INT '     
      
      EXEC sp_ExecuteSQL @sql, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                         @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, 
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                         @n_uombase,    @d_today,      @n_ShelfLife 
     
      IF @b_debug = 1
      BEGIN
         SELECT @sql    
      END
   END
END

GO