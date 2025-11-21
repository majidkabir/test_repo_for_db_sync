SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC    [dbo].[nspPRIDS03]
      @c_storerkey NVARCHAR(15) ,
      @c_sku       NVARCHAR(20) ,
      @c_lot       NVARCHAR(10) ,
      @c_lottable01 NVARCHAR(18) ,
      @c_lottable02 NVARCHAR(18) ,
      @c_lottable03 NVARCHAR(18) ,
      @d_lottable04 datetime ,
      @d_lottable05 datetime ,
      @c_uom        NVARCHAR(10) ,
      @c_facility   NVARCHAR(10)  ,  -- added By Ricky for IDSV5
      @n_uombase    int ,
      @n_qtylefttofulfill int
AS
BEGIN
   SET NOCOUNT ON 
    
   
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR
      FOR SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK)
      WHERE LOT.LOT = LOTATTRIBUTE.LOT
      AND LOTxLOCxID.Lot = LOT.LOT
      AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
      AND LOTxLOCxID.LOC = LOC.LOC
      AND LOC.Facility = @c_facility
      AND LOT.LOT = @c_lot
      ORDER BY LOTATTRIBUTE.LOTTABLE05
   END
ELSE
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR
      FOR
      SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,
             QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))
      FROM  LOT (nolock)
      INNER JOIN LOTxLOCxID (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT
      INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT
      INNER JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
      INNER JOIN ID (NOLOCK) ON ID.ID = LOTxLOCxID.ID
      LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)
                        FROM  PreallocatePickDetail p (NOLOCK), ORDERS (NOLOCK)
                        WHERE p.Orderkey = ORDERS.Orderkey
                        AND   p.Storerkey = @c_storerkey
                        AND   p.Sku = @c_sku
                        AND   p.Qty > 0
                        GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = p.Lot AND p.Facility = LOC.Facility
      WHERE LOTxLOCxID.Storerkey = @c_storerkey
      AND   LOTxLOCxID.SKU = @c_sku
      AND   LOC.Facility = @c_facility
      AND   LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' And LOC.LocationFlag <> 'HOLD' AND LOC.LocationFlag <> 'DAMAGE'  ---SOS120889: ADD LOC.LocationFlag <> 'DAMAGE' 
      GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.lottable05
      HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0
      ORDER BY LOTATTRIBUTE.lottable05
      -- End : SOS31895
   END
END

GO