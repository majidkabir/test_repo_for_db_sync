SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC    [dbo].[nspPrLotA1]
  	@c_storerkey NVARCHAR(15) ,
  	@c_sku NVARCHAR(20) ,
  	@c_lot NVARCHAR(10) ,
  	@c_lottable01 NVARCHAR(18) ,
  	@c_lottable02 NVARCHAR(18) ,
  	@c_lottable03 NVARCHAR(18) ,
  	@d_lottable04 datetime,
  	@d_lottable05 datetime,
  	@c_uom NVARCHAR(10),
   @c_facility NVARCHAR(10)  ,
  	@n_uombase int ,
  	@n_qtylefttofulfill int,
   @c_OtherParms NVARCHAR(200)
AS
BEGIN

IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
BEGIN
   DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
   QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
   FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
   WHERE LOT.LOT = LOTATTRIBUTE.LOT  
   AND LOTXLOCXID.Lot = LOT.LOT
   AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
   AND LOTXLOCXID.LOC = LOC.LOC
   AND LOC.Facility = @c_facility
   AND LOT.LOT = @c_lot
   ORDER BY LOTATTRIBUTE.LOTTABLE04
END
ELSE
BEGIN
   -- Get OrderKey and line Number
   DECLARE @c_OrderKey        NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5)
   
   IF dbo.fnc_RTrim(@c_OtherParms) IS NOT NULL AND dbo.fnc_RTrim(@c_OtherParms) <> ''
   BEGIN
      SELECT @c_OrderKey = LEFT(dbo.fnc_LTrim(@c_OtherParms), 10)
      SELECT @c_OrderLineNumber = SUBSTRING(dbo.fnc_LTrim(@c_OtherParms), 11, 5)
   END

    -- Get BillToKey
    DECLARE @n_ConsigneeMinShelfLife int,
            @c_LimitString           nvarchar(512) 
 
--     IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND dbo.fnc_RTrim(@c_OrderKey) <> ''
--     BEGIN
--        SELECT @n_ConsigneeMinShelfLife = ISNULL(STORER.MinShelfLife,0) 
--        FROM   ORDERS (NOLOCK)
--        JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
--        WHERE ORDERS.OrderKey = @c_OrderKey
-- 
--        IF @n_ConsigneeMinShelfLife > 0 
--        BEGIN
--           SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND DATEDIFF(day, GETDATE(), Lottable04) > " + CAST(@n_ConsigneeMinShelfLife as NVARCHAR(10))
--        END
--    END

   DECLARE @c_SQLStatement nvarchar(1024) 

   SELECT @c_SQLStatement = "DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
   " SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT," +
   " QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD)" +
   " FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)"  +
   " WHERE LOT.LOT = LOTATTRIBUTE.LOT" + 
   " AND LOTXLOCXID.Lot = LOT.LOT" +
   " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT" +
   " AND LOTXLOCXID.LOC = LOC.LOC" +
   " AND LOC.Facility = N'" + dbo.fnc_RTrim(@c_facility) + "'" + 
   " AND LOT.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "'" +
   " AND LOT.SKU = N'" + dbo.fnc_RTrim(@c_sku) + "'" +
   " AND LOT.STATUS = 'OK' " +
   " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 " +
   dbo.fnc_RTrim(@c_Limitstring) +
   " ORDER BY LOTATTRIBUTE.LOTTABLE04"

   EXECUTE(@c_SQLStatement)

   END
END

GO