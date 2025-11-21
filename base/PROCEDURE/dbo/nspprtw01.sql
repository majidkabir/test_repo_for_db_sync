SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nspPRTW01]
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
           @c_Condition NVARCHAR(510)

   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
      BEGIN

         /* Get Storer Minimum Shelf Life */
         SELECT @n_StorerMinShelfLife = ISNULL(Storer.MinShelflife, 0)
         FROM   STORER (NOLOCK)
         WHERE  STORERKEY = @c_lottable03
  
         SELECT @n_StorerMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_StorerMinShelfLife /100) * -1)
         FROM  Sku (nolock)
         WHERE Sku.Sku = @c_SKU
         AND   Sku.Storerkey = @c_Storerkey

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
         /* Lottable03 = Consignee Key */
         SELECT @n_StorerMinShelfLife = ISNULL(Storer.MinShelflife, 0)
         FROM   STORER (NOLOCK)
         WHERE  STORERKEY = dbo.fnc_RTrim(@c_lottable03)

         SELECT @n_StorerMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_StorerMinShelfLife /100) * -1)
         FROM  Sku (nolock)
         WHERE Sku.Sku = @c_SKU
         AND   Sku.Storerkey = @c_Storerkey

         IF @n_StorerMinShelfLife IS NULL
            SELECT @n_StorerMinShelfLife = 0

         -- lottable01 is used for loc.HostWhCode -- modified by Jeff
         IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
            BEGIN
               SELECT @c_Condition = " AND LOC.HostWhCode = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + "' "
            END

         IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
            BEGIN
               SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "' "
            END

         IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_Lottable04 IS NOT NULL
            BEGIN
               SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "' "
            END

         IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_Lottable05 IS NOT NULL
            BEGIN
               SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + "' "
            END

         -- if lottable04 is blank, then get candidate based on expiry date based on the following conversion.
         IF @n_StorerMinShelfLife <> 0 
            BEGIN
               IF CONVERT(char(10), @d_Lottable04, 103) = "01/01/1900" OR @d_Lottable04 IS NULL
                  BEGIN
                     SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND ( DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() " 
                     SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " OR Lotattribute.Lottable04 IS NULL ) "
                  END
            END

            SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= " + dbo.fnc_RTrim(CAST ( @n_uombase AS NVARCHAR(10) ) ) + " " 
            SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04 "
            SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot, SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) "
            -- select @c_condition

            EXEC (" DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
            " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) " + 
            " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (nolock), LOC (Nolock), ID (NOLOCK), SKUxLOC (NOLOCK) " + 
            " WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " +
            " AND LOT.SKU = N'" + @c_SKU + "' " +
            " AND LOT.STATUS = 'OK' " +
            " AND LOT.LOT = LOTATTRIBUTE.LOT " +
            " AND LOT.LOT = LOTXLOCXID.Lot " +
            " AND LOTXLOCXID.Loc = LOC.Loc " +
            " AND LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " + 
            " AND LOTXLOCXID.ID = ID.ID " +
            " AND ID.STATUS <> 'HOLD' " +  
            " AND LOC.Status = 'OK' " + 
	         " AND LOC.Facility = N'" + @c_facility + "' " +
		      " AND LOC.LocationFlag <> 'HOLD' " +
		      " AND LOC.LocationFlag <> 'DAMAGE' " +
				" AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " +
				" AND SKUxLOC.SKU = LOTxLOCxID.SKU " + 
			   " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +
			   " AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE') " + 
            " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 " + 
            " AND LOTxLOCxID.STORERKEY = N'" + @c_storerkey + "' " +
            " AND LOTxLOCxID.SKU = N'" + @c_SKU + "' " + 
            " AND LOTATTRIBUTE.STORERKEY = N'" + @c_storerkey + "' " +
            " AND LOTATTRIBUTE.SKU = N'" + @c_SKU + "' " + 
            @c_Condition  ) 

   END
END

GO