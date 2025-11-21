SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************\
* Modification Log                                                 *
*  By SHONG 9-Jan-2003                                             *
*     SOS# 9288 - Order cannot be fully allocated                  *
*     QtyAvailable Calculated Wrongly                              *
*                                                                  *
\******************************************************************/
CREATE PROC [dbo].[nspPRLOTA2]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_uom NVARCHAR(10), 
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN

DECLARE @n_StorerMinShelfLife int,
        @c_Condition NVARCHAR(510),
        @c_QtyToFulfill NVARCHAR(10)

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
AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
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

	
	-- SOS Ticket # 1059
	-- Request by Seik Inn
	-- Done By SHONG
	-- Original Script from nspPRIDS98
	-- Customize to accept LOT that Match any single last character of Batch#
	-- Purpose: At receiving stage, the Batch no(lottable02) for SB can be 20010101a, 
	-- 	20010101b, 20010101, 20010101c and so on. 
	--		The main concern for SB during shipment stage is on batch, so, 
	--		SB will specific the batch no to IDS for allocation, e.g. 20010101. 
	--    They dont' care either it is 20010101a, or 20010101b, or 20010101. 

   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
   BEGIN
      SELECT @c_Condition = " AND LOTATTRIBUTE.LOTTABLE02 LIKE N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "_' "
   END

	-- End Of Customization

   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "' "
   END
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + "' "
   END
   IF @d_Lottable04 <> '1900-01-01 00:00:00.000'
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "' "
   END
   IF @d_Lottable05 <> '1900-01-01 00:00:00.000'
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + "' "
   END

   SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) 

   SELECT @c_QtyToFulfill = CONVERT(char(10), @n_qtylefttofulfill)

   EXEC (" DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
         " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
         " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )  " +
         " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)     " + 
         " WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " +
         " AND LOT.SKU = N'" + @c_SKU + "' " +
         " AND LOT.STATUS = 'OK' " +
         " AND LOT.LOT = LOTATTRIBUTE.LOT " +
   	   " AND LOTXLOCXID.Lot = LOT.LOT " +
   	   " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +
   	   " AND LOTXLOCXID.LOC = LOC.LOC " +
         " AND LOTxLOCxID.ID = ID.ID " +
         " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
         " AND LOC.LocationFlag = 'NONE' " + 
   	   " AND LOC.Facility = N'" + @c_facility + "' " +
         @c_Condition  + 
         " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable04, Lotattribute.Lottable02 " +
         " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED)   > 0  " +
         " ORDER BY Lotattribute.Lottable04, " + 
         " Substring(lottable02, 5,2) + Substring(lottable02, 3,2) + Substring(lottable02, 1,2) + Substring(lottable02, 7,1) " +
         " ,LOT.Lot " )

END
END

GO