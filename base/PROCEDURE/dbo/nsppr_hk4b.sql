SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPR_HK4B                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 26-Mar-2012  Leong         SOS# 239608 - Exclude zero balance        */
/* 04-Sep-2013  Audrey        SOS# 288725 - Remove LOT.QtyPreallocated  */
/* 28-Aug-2017  TLTING  1.1   Dynamic SQL review, impact SQL cache log  */
/* 30-Aug-2017  Leong   1.2   fix @c_UOMBase to @n_uombase.             */
/* 01-Jun-2018 NJOW01   1.3   WMS-5194 add lottable06-15                */  
/* 18-Nov-2019  Wan01   1.4   Dynamic SQL review, impact SQL cache log  */  
/* 03-Jan-2020  CheeMun 1.5   INC0994141 - Revised Dynamic SQL          */       
/* 11-Mar-2021  LZG     1.6   INC1450421-Extended variable length (ZG01)*/                     
/************************************************************************/

CREATE PROC [dbo].[nspPR_HK4B]
     @c_storerkey        NVARCHAR(15)
   , @c_sku              NVARCHAR(20)
   , @c_lot              NVARCHAR(10)
   , @c_lottable01       NVARCHAR(18)
   , @c_lottable02       NVARCHAR(18)
   , @c_lottable03       NVARCHAR(18)
   , @d_lottable04       DATETIME
   , @d_lottable05       DATETIME
   , @c_lottable06       NVARCHAR(30)          
   , @c_lottable07       NVARCHAR(30)          
   , @c_lottable08       NVARCHAR(30)          
   , @c_lottable09       NVARCHAR(30)          
   , @c_lottable10       NVARCHAR(30)          
   , @c_lottable11       NVARCHAR(30)          
   , @c_lottable12       NVARCHAR(30)          
   , @d_lottable13       DATETIME           
   , @d_lottable14       DATETIME                 
   , @d_lottable15       DATETIME                 
   , @c_uom              NVARCHAR(10)
   , @c_facility         NVARCHAR(10)
   , @n_uombase          INT
   , @n_qtylefttofulfill INT
AS

DECLARE @b_success      int
      , @n_err          int
      , @c_errmsg       NVARCHAR(250)
      , @b_debug        int
      , @c_manual       NVARCHAR(1)
      , @c_LimitString  NVARCHAR(1000) -- ZG01 -- To limit the where clause based on the user input  
      , @c_Limitstring1 NVARCHAR(1000) -- ZG01
      , @n_shelflife    int

-- Added By SHONG 23.May.2002
-- IF the SKU.LOTTABLE04LABEL is BLANK, don't sort by Lottable04
DECLARE @c_Lottable04Label NVARCHAR(20)
      , @c_SortOrder       NVARCHAR(255)
      , @c_sql             NVARCHAR(MAX) = ''
      , @c_SQLParm         NVARCHAR(MAX) = ''

SELECT @b_success=0, @n_err=0, @c_errmsg="",@b_debug=0, @c_manual = 'N'

--DECLARE @c_UOMBase NVARCHAR(10)

--SELECT @c_UOMBase = @n_uombase

IF @d_lottable04 = '1900-01-01'
BEGIN
   SELECT @d_lottable04 = null
END

IF @d_lottable05 = '1900-01-01'
BEGIN
   SELECT @d_lottable05 = null
END

--NJOW01
IF @d_lottable13 = '1900-01-01'
BEGIN
   SELECT @d_lottable13 = null
END
IF @d_lottable14 = '1900-01-01'
BEGIN
   SELECT @d_lottable14 = null
END
IF @d_lottable15 = '1900-01-01'
BEGIN
   SELECT @d_lottable15 = null
END

IF @b_debug = 1
BEGIN
   SELECT "nspPR_HK01 : Before Lot Lookup ....."
   SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03
   SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  , '@c_sku' = @c_sku
   SELECT '@c_storerkey' = @c_storerkey, '@c_facility' = @c_facility
END

   -- when any of the lottables is supplied, get the specific lot
IF (@c_lottable01 <> '' OR @c_lottable02 <> '' OR @c_lottable03 <> '' OR
    @d_lottable04 IS NOT NULL OR @d_lottable05 IS NOT NULL OR
    @c_lottable06 <> '' OR @c_lottable07 <> '' OR @c_lottable08 <> '' OR  --NJOW01
    @c_lottable09 <> '' OR @c_lottable10 <> '' OR @c_lottable11 <> '' OR
    @c_lottable12 <> '' OR @d_lottable13 IS NOT NULL OR @d_lottable14 IS NOT NULL OR @d_lottable15 IS NOT NULL
    )
BEGIN
   SELECT @c_manual = 'N'
END

IF @b_debug = 1
BEGIN
   SELECT "nspPR_HK01 : After Lot Lookup ....."
   SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03
   SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual
   SELECT '@c_storerkey' = @c_storerkey
END

IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(@c_lot, 1) <> '*'
BEGIN
   /* Lot specific candidate set */
   DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD FOR
   SELECT MIN(LOT.STORERKEY), MIN(LOT.SKU), MIN(LOT.LOT),
           QTYAVAILABLE = CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) -
                                      SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) < @n_UOMBase
                               THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED)
                                    - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) )
                               WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) -
                                      SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) %  @n_UOMBase = 0
                               THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED)
                                    - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) )
                          ELSE
                              ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) )
                              -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % @n_UOMBase
                          END
   FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC  (NOLOCK)
   WHERE LOT.LOT = LOTATTRIBUTE.LOT
   AND LOTXLOCXID.Lot = LOT.LOT
   AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
   AND LOTXLOCXID.LOC = LOC.LOC
   AND LOC.Facility = @c_facility
   AND LOT.LOT = @c_lot
   AND (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) > 0 -- SOS# 239608/ 288725
   GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05
   ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05, MIN(LOC.LogicalLocation)

   IF @b_debug = 1
   BEGIN
      SELECT 'Lot not null'
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK)
      WHERE LOT.LOT = LOTATTRIBUTE.LOT AND LOT.LOT = @c_lot
      ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05
   END
END
ELSE
BEGIN
   /* Everything ELSE when no lottable supplied */
   IF @c_manual = 'N'
   BEGIN
    -- Added By SHONG 23.May.2002
      -- IF the SKU.LOTTABLE04LABEL is BLANK, don't sort by Lottable04
      -- order by lottable04, IF Lottable04 is not supplied, do not check the column
      -- SOS 7837 wally 6.sep.02
      -- it sku.lottable02label is blank, don't sort by lottable02
      DECLARE @c_Lottable02Label NVARCHAR(20)

      SELECT @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, ''), @c_Lottable02Label = isnull(lottable02label, '')
      FROM SKU (NOLOCK)
      WHERE SKU = @c_sku
      AND STORERKEY = @c_storerkey

      SELECT @c_SortOrder = ''
      IF @c_Lottable04Label <> ''
      BEGIN
         IF @c_lottable02label <> ''
            SELECT @c_SortOrder = " ORDER BY lotATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05, MIN(LOC.LogicalLocation) "
         ELSE
            SELECT @c_SortOrder = " ORDER BY lotATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.Lottable05, MIN(LOC.LogicalLocation) "
      END
      ELSE
      BEGIN
         IF @c_lottable02label <> ''
            SELECT @c_SortOrder = " ORDER BY LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05, MIN(LOC.LogicalLocation) "
         ELSE
            SELECT @c_SortOrder = " ORDER BY LOTATTRIBUTE.Lottable05, MIN(LOC.LogicalLocation) "
      END

      SELECT @c_LimitString = ''

      IF @c_lottable03 <> ' '
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= LTrim(RTrim(@c_lottable03)) "

      --NJOW01
      IF @c_lottable06 <> ' '
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable06= LTrim(RTrim(@c_lottable06)) " --(Wan01)
         
      IF @c_lottable07 <> ' '
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable07= LTrim(RTrim(@c_lottable07)) " --(Wan01)
         
      IF @c_lottable08 <> ' '
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable08= LTrim(RTrim(@c_lottable08)) " --(Wan01)
         
      IF @c_lottable09 <> ' '
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable09= LTrim(RTrim(@c_lottable09)) " --(Wan01)
         
      IF @c_lottable10 <> ' '
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable10= LTrim(RTrim(@c_lottable10)) " --(Wan01)
         
      IF @c_lottable11 <> ' '
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable11= LTrim(RTrim(@c_lottable11)) " --(Wan01)
         
      IF @c_lottable12 <> ' '
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable12= LTrim(RTrim(@c_lottable12)) " --(Wan01)

      IF @d_lottable13 IS NOT NULL AND @d_lottable13 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable13 = @d_lottable13 "              --(Wan01)

      IF @d_lottable14 IS NOT NULL AND @d_lottable14 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable14 = @d_lottable14 "              --(Wan01)

      IF @d_lottable15 IS NOT NULL AND @d_lottable15 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable15 = @d_lottable15 "              --(Wan01)

      IF @c_lottable02 <> ' '
      BEGIN       
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable02= LTrim(RTrim(@c_lottable02)) "

         --NJOW01
         IF @c_lottable06 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable06= LTrim(RTrim(@c_lottable06)) " --(Wan01)
            
         IF @c_lottable07 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable07= LTrim(RTrim(@c_lottable07)) " --(Wan01)
            
         IF @c_lottable08 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable08= LTrim(RTrim(@c_lottable08)) " --(Wan01)
            
         IF @c_lottable09 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable09= LTrim(RTrim(@c_lottable09)) " --(Wan01)
            
         IF @c_lottable10 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable10= LTrim(RTrim(@c_lottable10)) " --(Wan01)
            
         IF @c_lottable11 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable11= LTrim(RTrim(@c_lottable11)) " --(Wan01)
            
         IF @c_lottable12 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable12= LTrim(RTrim(@c_lottable12)) " --(Wan01)
         
         IF @d_lottable13 IS NOT NULL AND @d_lottable13 <> '1900-01-01'
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable13 = @d_lottable13 "              --(Wan01)
         
         IF @d_lottable14 IS NOT NULL AND @d_lottable14 <> '1900-01-01'
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable14 = @d_lottable14 "              --(Wan01)
         
         IF @d_lottable15 IS NOT NULL AND @d_lottable15 <> '1900-01-01'
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable15 = @d_lottable15 "              --(Wan01)
                           
         SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)
         SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)
         SELECT @c_sql = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
                          " SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT," +
                          " QTYAVAILABLE = CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
                          " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) < @n_UOMBase "+
                          " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
                             " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                          " WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
                              " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % @n_uombase = 0 " +
                           " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
                              " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                           " ELSE " +
                           " ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                           " -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % @n_uombase " +
                           " END " +
              " FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)" +
              " WHERE LOT.STORERKEY = @c_storerkey AND LOT.SKU = @c_sku " +
              " AND LOC.STATUS = 'OK' And LOC.LocationFlag = 'NONE' " +
              " AND lot.lot = lotattribute.lot AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.ID = ID.ID AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT AND LOTXLOCXID.LOC = LOC.LOC " +
              " AND LOC.FACILITY = @c_facility "  + @c_LimitString + " " +
              " AND (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) > 0 " + -- SOS# 239608/ 288725
              " GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " +
              " HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) >= @n_uombase " +
              @c_SortOrder

         SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +
                            '@c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18)' +       --(Wan01) 
                           ',@c_lottable06 NVARCHAR(30), @c_lottable07 NVARCHAR(30)' +       --(Wan01)   
                           ',@c_lottable08 NVARCHAR(30), @c_lottable09 NVARCHAR(30)' +       --(Wan01)   
                           ',@c_lottable10 NVARCHAR(30), @c_lottable11 NVARCHAR(30)' +       --(Wan01)   
                           ',@c_lottable12 NVARCHAR(30), @d_lottable13 DATETIME' +           --(Wan01)
                           ',@d_lottable14 DATETIME    , @d_lottable15 DATETIME' +           --(Wan01)
                           ',@n_UOMBase  INT '

         EXEC sp_ExecuteSQL @c_sql, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU
                           ,@c_Lottable02, @c_lottable03
                           ,@c_lottable06, @c_lottable07       --(Wan01)   
                           ,@c_lottable08, @c_lottable09       --(Wan01)   
                           ,@c_lottable10, @c_lottable11       --(Wan01)   
                           ,@c_lottable12, @d_lottable13       --(Wan01)
                           ,@d_lottable14, @d_lottable15       --(Wan01)
                           ,@n_UOMBase

      END
      ELSE
      BEGIN
         IF @c_lottable01 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= LTrim(RTrim(@c_lottable01)) "

         IF @c_lottable03 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= LTrim(RTrim(@c_lottable03)) "

         IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable04 = @d_lottable04 "

         IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable05 = @d_lottable05 "

         --NJOW01
         IF @c_lottable06 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable06= LTrim(RTrim(@c_lottable06)) "	--INC0994141
            
         IF @c_lottable07 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable07= LTrim(RTrim(@c_lottable07)) "	--INC0994141
            
         IF @c_lottable08 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable08= LTrim(RTrim(@c_lottable08)) "	--INC0994141
            
         IF @c_lottable09 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable09= LTrim(RTrim(@c_lottable09)) "	--INC0994141
            
         IF @c_lottable10 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable10= LTrim(RTrim(@c_lottable10)) "	--INC0994141
            
         IF @c_lottable11 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable11= LTrim(RTrim(@c_lottable11)) "	--INC0994141
            
         IF @c_lottable12 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable12= LTrim(RTrim(@c_lottable12)) "	--INC0994141
         
         IF @d_lottable13 IS NOT NULL AND @d_lottable13 <> '1900-01-01'
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable13 = @d_lottable13 "
         
         IF @d_lottable14 IS NOT NULL AND @d_lottable14 <> '1900-01-01'
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable14 = @d_lottable14 "
         
         IF @d_lottable15 IS NOT NULL AND @d_lottable15 <> '1900-01-01'
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable15 = @d_lottable15 "

         IF dbo.fnc_RTrim(@c_Lottable04Label) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable04Label) <> ''
         BEGIN
            IF LEFT(@c_lot,1) = '*'
            BEGIN
               SELECT @n_shelflife = CONVERT(int, substring(@c_lot, 2, 9))
               IF @n_shelflife < 13  -- it's month
               BEGIN
                   SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(char(8),Lottable04, 112) >= CONVERT(char(8), DATEADD(month, @n_shelflife, GETDATE()), 112) "
               END
               ELSE
               BEGIN
                   SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(char(8),Lottable04, 112) >= CONVERT(char(8), DATEADD(day, @n_shelflife, GETDATE()), 112) "
               END
            END
         END

         SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)
         SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)

         SELECT @c_sql = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
                         " SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT," +
                         " QTYAVAILABLE = CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
                                 " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) < @n_UOMBase " +
                           " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
                                " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                           " WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
                                 " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % @n_UOMBase = 0 " +
                           " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
                                 " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                           " ELSE " +
                           " ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                           " -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % @n_UOMBase " +
                           " END " +
                 " FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)" +
                 " WHERE LOT.STORERKEY = @c_storerkey AND LOT.SKU = @c_sku " +
                 " AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +
                 " AND lot.lot = lotattribute.lot AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.ID = ID.ID AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT AND LOTXLOCXID.LOC = LOC.LOC " +
                 " AND LOC.FACILITY = @c_facility "  + @c_LimitString + " " +
                 " AND (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) > 0 " + -- SOS# 239608/ 288725
                 " GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " +
                 " HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) >= @n_UOMBase " +
                 @c_SortOrder

         SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +
                            '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                            '@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME' +
                           ',@c_lottable06 NVARCHAR(30), @c_lottable07 NVARCHAR(30)' +       --(Wan01)   
                           ',@c_lottable08 NVARCHAR(30), @c_lottable09 NVARCHAR(30)' +       --(Wan01)   
                           ',@c_lottable10 NVARCHAR(30), @c_lottable11 NVARCHAR(30)' +       --(Wan01)   
                           ',@c_lottable12 NVARCHAR(30), @d_lottable13 DATETIME' +           --(Wan01)
                           ',@d_lottable14 DATETIME    , @d_lottable15 DATETIME' +           --(Wan01)
                           ',@n_UOMBase  INT,            @n_shelflife INT '

         EXEC sp_ExecuteSQL @c_sql, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU
                           ,@c_Lottable01, @c_Lottable02, @c_Lottable03
                           ,@d_Lottable04, @d_Lottable05
                           ,@c_lottable06, @c_lottable07       --(Wan01)   
                           ,@c_lottable08, @c_lottable09       --(Wan01)   
                           ,@c_lottable10, @c_lottable11       --(Wan01)   
                           ,@c_lottable12, @d_lottable13       --(Wan01)
                           ,@d_lottable14, @d_lottable15       --(Wan01)
                           ,@n_UOMBase,    @n_shelflife
      END
   END
END

GO