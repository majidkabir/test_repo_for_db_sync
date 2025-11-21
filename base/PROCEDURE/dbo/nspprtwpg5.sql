SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE PROC [dbo].[nspPRTWPG5]
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
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(20) = '' 
AS
BEGIN
   
   DECLARE @n_ConsigneeMinShelfLife int,
           @c_Condition NVARCHAR(1500)

	IF ISNULL(LTRIM(RTRIM(@c_lot)) ,'') <> '' AND
		LEFT(@c_LOT ,1) <> '*'
	BEGIN

      /* Get Storer Minimum Shelf Life */
      SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife, 0)
      FROM   STORER (NOLOCK)
      WHERE  STORERKEY = @c_lottable03

      SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_ConsigneeMinShelfLife /100) * -1)
      FROM  Sku (nolock)
      WHERE Sku.Sku = @c_SKU
      AND   Sku.Storerkey = @c_Storerkey

      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR 
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
      WHERE LOT.LOT = @c_lot 
      AND Lot.Lot = Lotattribute.Lot 
	   AND LOTXLOCXID.Lot = LOT.LOT
 	   AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
  	   AND LOTXLOCXID.LOC = LOC.LOC
   	AND LOC.Facility = @c_facility
      AND DateAdd(Day, @n_ConsigneeMinShelfLife, Lotattribute.Lottable04) > GetDate() 
      ORDER BY Lotattribute.Lottable04, Lot.Lot

   END
   ELSE
   BEGIN
--   	IF LEFT(@c_LOT,1) = '*'
   	BEGIN
   		DECLARE @c_OrderKey  NVARCHAR(10), 
   				  @c_OrderType NVARCHAR(10)
	   	
			IF LEN(@c_OtherParms) > 0 
   		BEGIN
   			SET @c_OrderKey = LEFT(@c_OtherParms,10) 
	   		
   			SET @c_OrderType = ''
   			SELECT @c_OrderType = TYPE 
   			FROM   ORDERS WITH (NOLOCK)
   			WHERE  OrderKey = @c_OrderKey
	   	
				IF RTRIM(ISNULL(@c_OrderType,'')) = 'VAS'
   			BEGIN
   				SELECT @c_Condition = RTRIM(@c_Condition) + " AND RIGHT(RTRIM(Lotattribute.Lottable02),1) <> 'Z' " 
   			END
   		END
   
			IF LEN(ISNULL(@c_LOT,'')) > 1
			BEGIN   			
	   		SELECT @n_ConsigneeMinShelfLife = CASE WHEN ISNUMERIC(RIGHT(@c_LOT, LEN(@c_LOT) - 1)) = 1 
                                                      THEN CAST(RIGHT(@c_LOT, LEN(@c_LOT) - 1) AS INT) * -1
                                                   ELSE 0
                                              END
			END

		END

      /* Get Storer Minimum Shelf Life */
      /* Lottable03 = Consignee Key */
		IF ISNULL(@n_ConsigneeMinShelfLife,0) = 0
		BEGIN 			
			SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife, 0)
			FROM   STORER (NOLOCK) 
			WHERE  STORERKEY = dbo.fnc_RTrim(@c_lottable03) 

			SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_ConsigneeMinShelfLife /100) * -1)
			FROM  Sku (nolock)
			WHERE Sku.Sku = @c_SKU
			AND   Sku.Storerkey = @c_Storerkey 

			IF @n_ConsigneeMinShelfLife IS NULL
				SELECT @n_ConsigneeMinShelfLife = 0 
		END

      -- lottable01 is used for loc.HostWhCode -- modified by Jeff
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOC.HostWhCode = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + "' "
      END

      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "' "
      END

      IF CONVERT(char(8), @d_Lottable04, 112) <> '19000101' AND @d_Lottable04 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND ( Lotattribute.Lottable04 >= N'" + dbo.fnc_RTrim(CONVERT(char(8), @d_Lottable04, 112)) + "' ) " 
      END
      ELSE
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND ( DateAdd(Day, " + CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() " 
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " OR Lotattribute.Lottable04 IS NULL ) "
      END

      -- SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= 1 " 
      SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05 "
      SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0 " 
		SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " ORDER BY Lotattribute.Lottable04,LOTATTRIBUTE.Lottable05, Lot.Lot "
--      SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + " ORDER BY SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) "

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
      " AND SKUxLOC.LocationType IN ('PICK', 'CASE') " + 
      " AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " +
      " AND SKUxLOC.SKU = LOTxLOCxID.SKU " + 
      " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +
      " AND LOTxLOCxID.STORERKEY = N'" + @c_storerkey + "' " +
      " AND LOTxLOCxID.SKU = N'" + @c_SKU + "' " + 
      " AND LOTATTRIBUTE.STORERKEY = N'" + @c_storerkey + "' " +
      " AND LOTATTRIBUTE.SKU = N'" + @c_SKU + "' " + 
      @c_Condition  ) 

   END
END


GO