SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR_HK4D                                         */
/* Creation Date: 09/09/2015                                            */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 351905 - Pre-allocation strategy for FrieslandHK            */
/*          Copy from nspPR_HK4B                                        */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspPR_HK4D]
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
   , @c_OtherParms       NVARCHAR(200) = '' 
AS

DECLARE @b_success      int
      , @n_err          int
      , @c_errmsg       NVARCHAR(250)
      , @b_debug        int
      , @c_manual       NVARCHAR(1)
      , @c_LimitString  NVARCHAR(255) -- To limit the where clause based on the user input
      , @c_Limitstring1 NVARCHAR(255)
      , @n_shelflife    int

-- Added By SHONG 23.May.2002
-- IF the SKU.LOTTABLE04LABEL is BLANK, don't sort by Lottable04
DECLARE @c_Lottable04Label NVARCHAR(20)
      , @c_SortOrder       NVARCHAR(255)
      , @c_Lottable01List  NVARCHAR(100)

SELECT @b_success=0, @n_err=0, @c_errmsg="",@b_debug=0, @c_manual = 'N'

DECLARE @c_UOMBase NVARCHAR(10)

SELECT @c_UOMBase = @n_uombase

IF @d_lottable04 = '1900-01-01'
BEGIN
   SELECT @d_lottable04 = null
END

IF @d_lottable05 = '1900-01-01'
BEGIN
   SELECT @d_lottable05 = null
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
    @d_lottable04 IS NOT NULL OR @d_lottable05 IS NOT NULL)
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
                                      SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) < @c_UOMBase
                               THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED)
                                    - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) )
                               WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) -
                                      SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) %  @c_UOMBase = 0
                               THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED)
                                    - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) )
                          ELSE
                              ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) )
                              -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % @c_UOMBase
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
      FROM LOT (Nolock), LOTATTRIBUTE (Nolock)
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

      IF @c_lottable02 <> ' '
      BEGIN
         IF @c_lottable01 <> ' '
         BEGIN
         	  IF CHARINDEX(';', @c_lottable01) > 0
         	  BEGIN         	  	
         	  	 SELECT @c_Lottable01List = @c_Lottable01List + '''' + LTRIM(RTRIM(ISNULL(ColValue,''))) + ''',' 
               FROM dbo.fnc_DelimSplit(';', @c_lottable01)   

               SELECT @c_Lottable01List = '(' + LEFT(@c_Lottable01List, LEN(@c_Lottable01List)-1) + ')'

               SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01 IN " + @c_Lottable01List
         	  END 
         	  ELSE
         	  BEGIN
               SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)) + "'"
            END
         END

         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable02= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable02)) + "'"
         
         IF @c_lottable03 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)) + "'"
            
         IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
            SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(char(8),Lottable04, 112) > N'"  + CONVERT(char(8), @d_lottable04, 112) + "'"
            
         SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)
         SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)
         EXEC (" DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
              " SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT," +
              " QTYAVAILABLE = CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
                              " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) < " + @c_UOMBase +
                        " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
                             " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                        " WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
                              " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % " + @c_UOMBase + " = 0 " +
              " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
                              " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                        " ELSE " +
                        " ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                        " -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % " + @c_UOMBase + " " +
                        " END " +
              " FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)" +
              " WHERE LOTXLOCXID.STORERKEY = N'" + @c_storerkey + "'" + " AND LOTXLOCXID.SKU = N'" + @c_sku + "' " +
              " AND LOC.STATUS = 'OK' And LOC.LocationFlag = 'NONE' " +
              " AND lot.lot = lotattribute.lot AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.ID = ID.ID AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT AND LOTXLOCXID.LOC = LOC.LOC " +
              " AND LOC.FACILITY = N'" + @c_facility + "'"  + @c_LimitString + " " +
              " AND (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) > 0 " + -- SOS# 239608/ 288725
              " GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " +
              " HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) >= " + @c_UOMBase + " " +
              @c_SortOrder)
      END
      ELSE
      BEGIN
         IF @c_lottable01 <> ' '
         BEGIN
         	  IF CHARINDEX(';', @c_lottable01) > 0
         	  BEGIN         	  	
         	  	 SELECT @c_Lottable01List = @c_Lottable01List + '''' + LTRIM(RTRIM(ISNULL(ColValue,''))) + ''',' 
               FROM dbo.fnc_DelimSplit(';', @c_lottable01)   

               SELECT @c_Lottable01List = '(' + LEFT(@c_Lottable01List, LEN(@c_Lottable01List)-1) + ')'

               SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01 IN " + @c_Lottable01List
         	  END 
         	  ELSE
         	  BEGIN
               SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)) + "'"
            END
         END

         IF @c_lottable03 <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)) + "'"

         IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
            SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(char(8),Lottable04, 112) > N'"  + CONVERT(char(8), @d_lottable04, 112) + "'"
            --SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable04 = N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable04))) + "'"

         IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable05= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable05))) + "'"

         IF dbo.fnc_RTrim(@c_Lottable04Label) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable04Label) <> ''
         BEGIN
            IF LEFT(@c_lot,1) = '*'
            BEGIN
               SELECT @n_shelflife = CONVERT(int, substring(@c_lot, 2, 9))
               IF @n_shelflife < 13  -- it's month
               BEGIN
                   SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(char(8),Lottable04, 112) >= N'"  + CONVERT(char(8), DATEADD(month, @n_shelflife, GETDATE()), 112) + "'"
               END
               ELSE
               BEGIN
                   SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(char(8),Lottable04, 112) >= N'" + CONVERT(char(8), DATEADD(day, @n_shelflife, GETDATE()), 112) + "'"
               END
            END
         END

         SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)
         SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)

         EXEC (" DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
                 " SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT," +
                 " QTYAVAILABLE = CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
                                 " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) < " + @c_UOMBase +
                           " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
                                " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                           " WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
                                 " SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % " + @c_UOMBase + " = 0 " +
                           " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
                                 " - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                           " ELSE " +
                           " ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) " +
                           " -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) % " + @c_UOMBase + " " +
                           " END " +
                 " FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)" +
                 " WHERE LOTXLOCXID.STORERKEY = N'" + @c_storerkey + "'" + " AND LOTXLOCXID.SKU = N'" + @c_sku + "' " +
                 " AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +
                 " AND lot.lot = lotattribute.lot AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.ID = ID.ID AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT AND LOTXLOCXID.LOC = LOC.LOC " +
                 " AND LOC.FACILITY = N'" + @c_facility + "'"  + @c_LimitString + " " +
                 " AND (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) > 0 " + -- SOS# 239608/ 288725
                 " GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " +
                 " HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) >= " + @c_UOMBase + " " +
                 @c_SortOrder)
      END
   END
END

GO