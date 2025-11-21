SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspPR_Lot0]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@c_lottable04 datetime ,
@c_lottable05 datetime ,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(10),  -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(20) = ''  --Orderinfo4PreAllocation   
AS
BEGIN
   
   DECLARE @b_success int, @n_err int, @c_errmsg NVARCHAR(250), @b_debug int
   DECLARE @c_LimitString NVARCHAR(255) -- To limit the where clause based on the user input

   SELECT @b_success=0, @n_err=0, @c_errmsg="",@b_debug=0

   SELECT @b_debug = 0

   -- Add by June (SOS11587)
   DECLARE @c_UOMBase NVARCHAR(10)
   IF @n_uombase <= 0 SELECT @n_uombase = 1
   SELECT @c_UOMBase = @n_uombase

   IF ISNULL(RTRIM(@c_lot),'') <> ''
   BEGIN
      /* Lot specific candidate set */
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      -- Start - Changed by June 11.AUG.03 (SOS13375), Use PreallocatePickdetail instead of Lot For QtyPreallcoated
      SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,
      -- Start Add by June 3.June.03 (SOS11587)
      -- QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < @c_UOMBase
                        THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
                        WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % @c_UOMBase = 0
                        THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
                        ELSE
                        SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
                        - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % @c_UOMBase)
                     END
      -- End (SOS11587)
      FROM LOT (nolock)
      INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT  
      INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT
      INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
      LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)
      FROM   PreallocatePickDetail p (NOLOCK), ORDERS (NOLOCK)
      WHERE  p.Orderkey = ORDERS.Orderkey
      GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility
      WHERE LOC.Facility = @c_facility
      AND   LOT.LOT = @c_lot
      --AND   loc.locationtype <> 'XDOCK'
      AND  LOC.LOCATIONTYPE ='PICK' --AAY001 Allocate from Tagged PickFace
      -- SOS11587
      GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05
      ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05
      -- End - Changed by June 11.AUG.03 (SOS13375)
   END
   ELSE
   BEGIN
      SELECT @c_LimitString = ''
      IF RTRIM(@c_lottable01) <> ''
      SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND Lottable01= '" + RTRIM(@c_lottable01) + "'"

      IF RTRIM(@c_lottable02) <> ''
      SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND lottable02= '" + RTRIM(@c_lottable02) + "'"

      IF RTRIM(@c_lottable03) <> ''
      SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND lottable03= '" + RTRIM(@c_lottable03) + "'"

      --	IF @c_lottable04 IS NOT NULL AND @c_lottable04 <> Convert(datetime, NULL)
      IF @c_lottable04 <> ( select convert(datetime,'01/01/1900' ))
      SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND lottable04= '" + RTRIM(CONVERT(char(20), @c_lottable04)) + "'"

      IF @b_debug = 1
      BEGIN
         select 'lot4' = @c_lottable04
         select 'sting' = " AND lottable04= '" + RTRIM(CONVERT(char(20), @c_lottable04)) + "'"
      END
   
      --	IF @c_lottable05 IS NOT NULL AND @c_lottable05 <> Convert(datetime, NULL)
      IF @c_lottable05 <> ( select convert(datetime,'01/01/1900' ))
      SELECT @c_LimitString =  RTRIM(@c_LimitString) + " AND lottable05= '" + RTRIM(CONVERT(char(20), @c_lottable05)) + "'"

      SELECT @c_StorerKey = RTRIM(@c_StorerKey)
      SELECT @c_Sku = RTRIM(@c_SKU)

      -- Start - Changed by June 11.AUG.03 (SOS13375), Use PreallocatePickdetail instead of Lot For QtyPreallcoated
      EXEC ("DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
      "SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
      -- Changed by June 11.Aug.03 (SOS13375) - To obtain QtyPreallocated from PreallocatePickdetail table instead of LOT
      -- Start - Changed by June 3.June.03 (SOS11587)
      -- QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD)
      "QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < " + @c_UOMBase +
      "					 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      "					 WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " +
      "					 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      "					 ELSE   " +
      "							 SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      "							 - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +
      "					 END " +
      -- End (SOS11587)
      "FROM LOTXLOCXID (NOLOCK) " +
      -- Start - Changed by June 11.Aug.03 (SOS13375) - To obtain QtyPreallocated from PreallocatePickdetail table instead of LOT
      "INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot " +
      "INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +
      "INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
      -- Change by Shong on 28-Nov-2003, Suggestion from Manny to include SKU into Select statement 
      "LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) " +
      "					  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
      "					  WHERE  p.Orderkey = ORDERS.Orderkey " +
      "					  AND    p.Storerkey = '" + @c_storerkey + "' " +
      "					  AND    p.SKU = '" + @c_sku + "' " +
      "					  AND    p.Qty > 0 " +
      "					  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility	" +
      -- End (SOS13375)
      "WHERE LOT.STORERKEY = '" + @c_storerkey + "' " +
      "AND LOT.SKU = '" + @c_sku + "' " +
		-- SOS20556
      -- "AND LOT.STATUS = 'OK' " +
		"AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND LOC.LocationFlag = 'NONE' " +
      "AND loc.locationtype <> 'XDOCK' " +
      -- SOS11587
      -- (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0
      -- AND lot.lot = lotattribute.lot
      -- AND LOTXLOCXID.Lot = LOT.LOT
      -- AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
      -- AND LOTXLOCXID.LOC = LOC.LOC
      "AND LOC.Facility = '" + @c_facility + "'" + @c_LimitString + " " +
      "AND LOC.LOCATIONTYPE = 'PICK' " + --AAY001 Tagged Pick Face
      -- Add by June (SOS11587)
      "GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05  " +
      --HAVING SUM(LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) >=   36
      "HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= " + @c_UOMBase + " " +
      -- End SOS11587      
      " ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 ")
      -- End - Changed by June 11.AUG.03 (SOS13375)
   END
END

GO