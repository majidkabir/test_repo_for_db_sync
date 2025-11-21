SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC    [dbo].[nspPRSL423]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN

DECLARE @n_StorerMinShelfLife int,
        @c_Condition NVARCHAR(510), @c_currentdate NVARCHAR(18) 


select @c_currentdate = convert(char(4), datepart(year, GetDate())) 
 + (replicate('0', 2-len(convert(char(2), datepart(wk, GetDate())))) +
 convert(char(2), datepart(wk, GetDate())))

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
QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK)
WHERE LOT.LOT = @c_lot 
AND Lot.Lot = Lotattribute.Lot 
AND LOTXLOCXID.Lot = LOT.LOT
AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
AND LOTXLOCXID.LOC = LOC.LOC
AND LOC.Facility = @c_facility
AND ((Lotattribute.Lottable04 IS NULL AND dbo.fnc_RTrim(Lotattribute.Lottable03) >= + " N'" + dbo.fnc_RTrim(@c_currentdate) + "' " ) 
 OR (Lotattribute.Lottable04 IS NOT NULL AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() ))
ORDER BY Lotattribute.Lottable04 DESC, Lotattribute.Lottable02, Lotattribute.Lottable03, Lot.Lot

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

   SELECT @c_Condition = " AND ((Lotattribute.Lottable04 IS NULL AND dbo.fnc_RTrim(Lotattribute.Lottable03) >= N'" + dbo.fnc_RTrim(@c_currentdate) + "')" 
	       + " OR (Lotattribute.Lottable04 IS NOT NULL AND DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() )) "
          + dbo.fnc_RTrim(@c_Condition) 
			 + " ORDER BY Lotattribute.Lottable04 DESC, Lotattribute.Lottable02, Lotattribute.Lottable03, Lot.Lot"


   EXEC (" DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
         " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
         " QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) " + 
         " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK) " +
         " WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " +
         " AND LOT.SKU = N'" + @c_SKU + "' " +
         " AND LOT.STATUS = 'OK' " +
         " AND LOT.LOT = LOTATTRIBUTE.LOT " +
	 " AND LOTXLOCXID.Lot = LOT.LOT " +
	 " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +
	 " AND LOTXLOCXID.LOC = LOC.LOC " +
	 " AND LOC.Facility = N'" + @c_facility + "' " +
         " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 " +
         @c_Condition  ) 

END
END

GO