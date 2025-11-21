SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nspPRIDS5A]
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
   FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK) 
   WHERE LOT.LOT = LOTATTRIBUTE.LOT  
   AND LOTXLOCXID.Lot = LOT.LOT
   AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
   AND LOTXLOCXID.LOC = LOC.LOC
   AND LOTXLOCXID.ID  = ID.ID  --added by ang(SOS131215)
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
 
    IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND dbo.fnc_RTrim(@c_OrderKey) <> ''
    BEGIN
       SELECT @n_ConsigneeMinShelfLife = ISNULL(STORER.MinShelfLife,0) 
       FROM   ORDERS (NOLOCK)
       JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
       WHERE ORDERS.OrderKey = @c_OrderKey

       -- Modified By SHONG on 8th Apr 2003
       -- Change condition greater or equal to..
       IF @n_ConsigneeMinShelfLife > 0 
       BEGIN
          SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND DATEDIFF(day, GETDATE(), Lottable04) >= " + CAST(@n_ConsigneeMinShelfLife as NVARCHAR(10))
       END
   END

   DECLARE @c_SQLStatement nvarchar(1024) 

   SELECT @c_SQLStatement = "DECLARE  PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY FOR " +
   " SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT," +
	-- Start : SOS24348
	-- " QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD)" +
   " QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) - MIN(LOT.QTYONHOLD)" +
	-- End : SOS24348
   " FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)"  +
   " WHERE LOT.LOT = LOTATTRIBUTE.LOT" + 
   " AND LOTXLOCXID.Lot = LOT.LOT" +
   " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT" +
   " AND LOTXLOCXID.LOC = LOC.LOC" +
   " AND LOTXLOCXID.ID  = ID.ID " + --added by ang(SOS131215) 
   " AND LOC.Facility = N'" + dbo.fnc_RTrim(@c_facility) + "'" + 
   " AND LOT.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "'" +
   " AND LOT.SKU = N'" + dbo.fnc_RTrim(@c_sku) + "'" +
   " AND LOT.STATUS = 'OK' " +
   " AND LOC.STATUS = 'OK' " + --added by ang(SOS131215) START
   " AND ID.STATUS = 'OK' " +  
   " AND LOC.LocationFlag <> 'HOLD' " +
   " AND LOC.LocationFlag <> 'DAMAGE' " + --added by ang(SOS131215) END
	-- SOS24348
   -- " AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0 " +
   dbo.fnc_RTrim(@c_Limitstring) +
	-- Start : SOS24348
	" GROUP BY LOT.STORERKEY,LOT.SKU,LOT.LOT, LOTATTRIBUTE.LOTTABLE04 " +
   " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) - MIN(QTYONHOLD) > 0 " +
	-- End : SOS24348
   " ORDER BY LOTATTRIBUTE.LOTTABLE04"

   EXECUTE(@c_SQLStatement)

   END
END


GO