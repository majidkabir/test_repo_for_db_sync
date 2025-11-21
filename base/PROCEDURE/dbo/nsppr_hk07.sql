SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR_HK07                                         */
/* Creation Date: 29-Nov-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: Created based on nspPR_HK05 for WTC Indent Process.         */
/*          To allocate stocks with LOC.LocationCategory <> 'SELECTIVE' */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 26-Mar-2012  Leong         SOS# 239608 - Exclude zero balance        */
/* 04-Sep-2013  Audrey        SOS# 288725 - Remove LOT.QtyPreallocated  */
/* 17-Jan-2020  Wan01    1.2  Dynamic SQL review, impact SQL cache log  */  
/************************************************************************/

CREATE PROC [dbo].[nspPR_HK07]
     @c_storerkey        NVARCHAR(15)
   , @c_sku              NVARCHAR(20)
   , @c_lot              NVARCHAR(10)
   , @c_lottable01       NVARCHAR(18)
   , @c_lottable02       NVARCHAR(18)
   , @c_lottable03       NVARCHAR(18)
   , @d_lottable04       datetime
   , @d_lottable05       datetime
   , @c_uom              NVARCHAR(10)
   , @c_facility         NVARCHAR(10)
   , @n_uombase          int
   , @n_qtylefttofulfill int
AS
BEGIN
   DECLARE @b_success      int
         , @n_err          int
         , @c_errmsg       NVARCHAR(250)
         , @b_debug        int
         , @c_manual       NVARCHAR(1)
         , @c_LimitString  NVARCHAR(255) -- To limit the where clause based on the user input
         , @c_Limitstring1 NVARCHAR(255)
         , @n_shelflife    int

   -- Added By SHONG 23.May.2002
   -- If the SKU.LOTTABLE04LABEL is BLANK, don't sort by Lottable04
   DECLARE @c_Lottable04Label NVARCHAR(20)
         , @c_SortOrder       NVARCHAR(255)
         , @c_UOMBase         NVARCHAR(10)
         , @c_SQL             NVARCHAR(4000) = ''        --(Wan01)
         , @c_SQLParms        NVARCHAR(4000) = ''        --(Wan01)   

   SELECT @b_success = 0, @n_err = 0, @c_errmsg = '', @b_debug = 0, @c_manual = 'N'
   SELECT @c_UOMBase = @n_uombase

   IF @d_lottable04 = '1900-01-01'
   BEGIN
      SELECT @d_lottable04 = NULL
   END

   IF @d_lottable05 = '1900-01-01'
   BEGIN
      SELECT @d_lottable05 = NULL
   END

   IF @b_debug = 1
   BEGIN
      SELECT 'nspPR_HK07 : Before Lot Lookup .....'
      SELECT '@c_lot' = @c_lot,'@c_lottable01' = @c_lottable01, '@c_lottable02' = @c_lottable02, '@c_lottable03' = @c_lottable03
      SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  , '@c_sku' = @c_sku
      SELECT '@c_storerkey' = @c_storerkey, '@c_facility' = @c_facility
   END

   IF ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)),'') <> '' AND LEFT(@c_lot, 1) <> '*'
   BEGIN
      /* Lot specific candidate set */
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,
             QTYAVAILABLE = CASE WHEN ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED ) <  @n_UOMBase
                                 THEN ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED  )
                                 WHEN ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED  ) % @n_UOMBase = 0
                                 THEN ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED  )
                                 ELSE ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED )
                                    - ( LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED ) % @n_UOMBase
                            END
      FROM LOT (NOLOCK)
      JOIN LOTATTRIBUTE (NOLOCK) ON ( LOT.LOT = LOTATTRIBUTE.LOT )
      JOIN LOTXLOCXID (NOLOCK) ON ( LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT )
      JOIN LOC (NOLOCK) ON ( LOTXLOCXID.LOC = LOC.LOC )
      WHERE LOC.Facility = @c_facility
      AND LOT.LOT = @c_lot
      AND (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) > 0 -- SOS# 239608/ 288725
      ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.Lottable02, LOC.LogicalLocation
   END
   ELSE
   BEGIN
       /* Everything Else when no lottable supplied */
       SELECT @c_LimitString = ''

       IF @c_lottable01 <> ' '
          SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= @c_lottable01"

       IF @c_lottable02 <> ' '
          SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND lottable02= @c_lottable02"

       IF @c_lottable03 <> ' '
          SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= @c_lottable03"

       IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
          SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND lottable04 = @d_lottable04"

       IF @d_lottable05 IS NOT NULL AND @d_lottable05 <> '1900-01-01'
          SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND lottable05= @d_lottable05"

       -- Added By SHONG 23.May.2002
       -- If the SKU.LOTTABLE04LABEL is BLANK, don't sort by Lottable04
       -- order by lottable04, if Lottable04 is not supplied, do not check the column
       SELECT @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, '')
         FROM SKU (NOLOCK)
        WHERE SKU = @c_sku
          AND STORERKEY = @c_storerkey

       SELECT @c_SortOrder = ''

       IF ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable04Label)),'') <> ''
       BEGIN
          SELECT @c_SortOrder = " ORDER BY lotATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.Lottable02, MIN(LOC.LogicalLocation) "
       END
       ELSE
       BEGIN
          SELECT @c_SortOrder = " ORDER BY LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.Lottable02, MIN(LOC.LogicalLocation) "
       END

       IF ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable04Label)),'') <> ''
       BEGIN
          IF LEFT(@c_lot,1) = '*'
          BEGIN
             SELECT @n_shelflife = CONVERT(INT, SUBSTRING(@c_lot, 2, 9))
             IF @n_shelflife < 13  -- it's month
             BEGIN
                SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(char(8),Lottable04, 112) >= CONVERT(CHAR(8), DATEADD(MONTH, @n_shelflife, GETDATE()), 112)"
             END
             ELSE
             BEGIN
                SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(char(8),Lottable04, 112) >= CONVERT(CHAR(8), DATEADD(DAY, @n_shelflife, GETDATE()), 112)"
             END
          END
       END

       IF @b_debug = 1
       BEGIN
          SELECT 'c_limitstring', @c_limitstring
       END

       SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)
       SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)

      --(Wan01) - START  
       SET @c_SQL = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
             " SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT," +
             " QTYAVAILABLE = ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
             " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
             " FROM LOT (NOLOCK) " +
             " JOIN LOTATTRIBUTE (NOLOCK) ON ( LOT.lot = LOTATTRIBUTE.lot ) " +
             " JOIN LOTXLOCXID (NOLOCK) ON ( LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ) " +
             " JOIN LOC (NOLOCK) ON ( LOTXLOCXID.LOC = LOC.LOC ) " +
             " JOIN ID (NOLOCK) ON ( LOTXLOCXID.ID = ID.ID ) " +
             " WHERE LOTXLOCXID.STORERKEY = @c_storerkey AND LOTXLOCXID.SKU = @c_sku " +
             " AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +
             " AND LOC.LocationCategory <> 'SELECTIVE' " +
             " AND LOC.FACILITY = @c_facility"  + @c_LimitString + " " +
             " AND (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) > 0 " + -- SOS# 239608
             " GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " +
             " HAVING (SUM(LOTXLOCXID.Qty) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QtyPicked) - MIN(LOT.QtyPreAllocated) ) > 0 " +
             @c_SortOrder 

       SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                      + ',@c_storerkey  NVARCHAR(15)'
                      + ',@c_SKU        NVARCHAR(20)'
                      + ',@c_Lottable01 NVARCHAR(18)'
                      + ',@c_Lottable02 NVARCHAR(18)'
                      + ',@c_Lottable03 NVARCHAR(18)'
                      + ',@d_lottable04 datetime'
                      + ',@d_lottable05 datetime'
                      + ',@n_shelflife  int'
                      + ',@n_UOMBase    int'
                    
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU 
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                        ,@n_shelflife, @n_UOMBase  
      --(Wan01) - END  

   END
END

GO