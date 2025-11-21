SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************************
* SOS29977  - Changed by June 07.Dec.2004
*           - Remove manual = 'N' section 
*           - order by lot04 & lo05 instead of lot & include lot04 & lot05 in GROUP BY
* SOS122133 - Change By Shong 30.Apr.2009
*           - Add new parameter @c_OtherParms
*
/* Date         Author  Ver   Purposes                                  */ 
/* 21-Nov-2019  TLTING  1.1   Dynamic SQL review, impact SQL cache log  */ 
*********************************************************************************************/

CREATE PROC [dbo].[nspPR_Lot]
   @c_storerkey NVARCHAR(15) ,
   @c_sku NVARCHAR(20) ,
   @c_lot NVARCHAR(10) ,
   @c_lottable01 NVARCHAR(18) ,
   @c_lottable02 NVARCHAR(18) ,
   @c_lottable03 NVARCHAR(18) ,
   @c_lottable04 datetime ,
   @c_lottable05 datetime ,
   @c_uom        NVARCHAR(10) ,
   @c_facility   NVARCHAR(10),  -- added By Ricky for IDSV5
   @n_uombase    int ,
   @n_qtylefttofulfill int,
   @c_OtherParms NVARCHAR(200) = ''
AS
BEGIN
   
   DECLARE @b_success int, @n_err int, @c_errmsg NVARCHAR(250), @b_debug int
   DECLARE @c_LimitString NVARCHAR(255) -- To limit the where clause based on the user input

   DECLARE @c_SQLStatement nvarchar(3999)   = ''
   DECLARE @c_SQLParm nvarchar(3999)  = '' 

   SELECT @b_success=0, @n_err=0, @c_errmsg="",@b_debug=0

   SELECT @b_debug = 0

   -- Add by June (SOS11587)
   DECLARE @c_UOMBase NVARCHAR(10)

   IF @n_uombase <= 0 
      SELECT @n_uombase = 1

   SELECT @c_UOMBase = @n_uombase

   IF ISNULL(RTRIM(@c_lot), '') <> ''
   BEGIN
      /* Lot specific candidate set */
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      -- Start - Changed by June 11.AUG.03 (SOS13375), Use PreallocatePickdetail instead of Lot For QtyPreallcoated
      SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,
      -- Start Add by June 3.June.03 (SOS11587)
      -- QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < @n_UOMBase
                        THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
                        WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % @n_UOMBase = 0
                        THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
                        ELSE
                        SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
                        - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % @n_UOMBase)
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
      AND   LOC.locationtype <> 'XDOCK'
      -- SOS11587
      GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05
      ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05
      -- End - Changed by June 11.AUG.03 (SOS13375)
   END
   ELSE
   BEGIN
      SELECT @c_LimitString = ''
      IF LTrim(RTrim(@c_lottable01)) <> ' '
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND Lottable01= LTrim(RTrim(@c_lottable01))"

      IF LTrim(RTrim(@c_lottable02)) <> ' '
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND lottable02= LTrim(RTrim(@c_lottable02)) "

      IF LTrim(RTrim(@c_lottable03)) <> ' '
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND lottable03= LTrim(RTrim(@c_lottable03)) "

      --	IF @c_lottable04 IS NOT NULL AND @c_lottable04 <> Convert(datetime, NULL)
      IF @c_lottable04 <> ( select convert(datetime,'01/01/1900' ))
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND lottable04= @c_lottable04 "

      IF @b_debug = 1
      BEGIN
         select 'lot4' = @c_lottable04
         select 'sting' = " AND lottable04= N'" + LTrim(RTrim(CONVERT(char(20), @c_lottable04))) + "'"
      END
   
      --	IF @c_lottable05 IS NOT NULL AND @c_lottable05 <> Convert(datetime, NULL)
      IF @c_lottable05 <> ( select convert(datetime,'01/01/1900' ))
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND lottable05= @c_lottable05 "

      SELECT @c_StorerKey = RTrim(@c_StorerKey)
      SELECT @c_Sku = RTrim(@c_SKU)

      -- Start - Changed by June 11.AUG.03 (SOS13375), Use PreallocatePickdetail instead of Lot For QtyPreallcoated
       
      SELECT @c_SQLStatement = "DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
      "SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
      -- Changed by June 11.Aug.03 (SOS13375) - To obtain QtyPreallocated from PreallocatePickdetail table instead of LOT
      -- Start - Changed by June 3.June.03 (SOS11587)
      -- QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD)
      "QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < @n_uombase " +
      "					 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      "					 WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % @n_uombase = 0 " +
      "					 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      "					 ELSE   " +
      "							 SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
      "							 - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % @n_uombase ) " +
      "					 END " +
      -- End (SOS11587)
      "FROM LOTXLOCXID (NOLOCK) " +
      -- Start - Changed by June 11.Aug.03 (SOS13375) - To obtain QtyPreallocated from PreallocatePickdetail table instead of LOT
      "INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot " +
      "INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +
      "INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
      "INNER JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID " +  --Add by ang(SOS131215)
      -- Change by Shong on 28-Nov-2003, Suggestion from Manny to include SKU into Select statement 
      "LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) " +
      "					  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
      "					  WHERE  p.Orderkey = ORDERS.Orderkey " +
      "					  AND    p.Storerkey = @c_storerkey " +
      "					  AND    p.SKU = @c_sku " +
      "					  AND    p.Qty > 0 " +
      "					  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility	" +
      -- End (SOS13375)
      "WHERE LOT.STORERKEY = @c_storerkey " +
      "AND LOT.SKU = @c_sku " +
		-- SOS20556
      -- "AND LOT.STATUS = 'OK' " +
		"AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND LOC.LocationFlag = 'NONE' " +
      "AND ID.STATUS ='OK' " + --Add by ang(SOS131215)
      "AND loc.locationtype <> 'XDOCK' " +
      "AND LOC.Facility = @c_facility " + @c_LimitString + " " +
      -- Add by June (SOS11587)
      "GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05  " +
      --HAVING SUM(LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) >=   36
      "HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= @n_UOMBase " +
      -- End SOS11587      
      " ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 "
      -- End - Changed by June 11.AUG.03 (SOS13375)


      SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +   
         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +
            '@c_Lottable03 NVARCHAR(18), @c_Lottable04 DATETIME,     @c_Lottable05 DATETIME, @n_uombase INT '       
      
      EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU,  @c_Lottable01, @c_Lottable02, @c_Lottable03,
                        @c_Lottable04, @c_Lottable05, @n_uombase  



   END
END

GO