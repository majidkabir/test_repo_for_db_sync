SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR_TH02                                         */
/* Creation Date:04-Aug-2014                                            */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: PreAllocateStrategy : SOS#317357                            */
/*                                                                      */
/* Called By: nspOrderProcessing		                                    */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author Ver. Purposes                                    */
/************************************************************************/

CREATE PROC [dbo].[nspPR_TH02]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(5),    -- added By Vicky for IDSV5 
@n_uombase int ,
@n_qtylefttofulfill INT,
@c_OtherParms NVARCHAR(200)=''
AS
BEGIN
   
   DECLARE @n_StorerMinShelfLife INT,
           @c_Condition          NVARCHAR(510),
           @c_SQLStatement       NVARCHAR(3999),
	         @c_OrderKey           NVARCHAR(10),
	         @c_OrderLineNumber    NVARCHAR(5),
	         @c_Type               NVARCHAR(10),
	         @d_DeliveryDate       DATETIME,
	         @c_UOM3               NVARCHAR(10)           
           
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Preallocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)
      
      SELECT TOP 1 @c_type = O.Type, 
             @d_DeliveryDate = O.DeliveryDate,
             @c_UOM3 = PACK.PackUOM3
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.OrderKey = OD.OrderKey
      JOIN SKU (NOLOCK) ON OD.StorerKey = SKU.Storerkey AND OD.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      WHERE O.OrderKey = @c_OrderKey
      AND OD.OrderLineNumber = @c_OrderLineNumber       
   END       
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      /* Get Storer Minimum Shelf Life */
      
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey
      AND Sku.Facility = @c_facility  -- added By Vicky for IDSV5 
      
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (Nolock), Lotattribute (Nolock)
      WHERE LOT.LOT = @c_lot 
      AND Lot.Lot = Lotattribute.Lot 
      AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
      ORDER BY Lotattribute.Lottable05, Lot.Lot

   END
   ELSE
   BEGIN
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey
      AND Sku.Facility = @c_facility  -- added By Vicky for IDSV5 
   
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
      
      IF @c_Type = '3' AND @c_UOM3 = 'PACK'
      BEGIN      	
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DATEDIFF(DAY, LOTTABLE04,'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_DeliveryDate, 106)) +"') IN (0,1,2) "
      END      
      ELSE IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "' "
      END
      
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + "' "
      END
   
      IF @n_StorerMinShelfLife > 0 
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() " 
      END 
      
     SELECT @c_SQLStatement =  " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
            " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )  " +
            " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)     " + 
            " WHERE LOT.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "' " +
            " AND LOT.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "' " +
            " AND LOT.STATUS = 'OK' " +
            " AND LOT.LOT = LOTATTRIBUTE.LOT " +
      	   " AND LOTXLOCXID.Lot = LOT.LOT " +
      	   " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +
      	   " AND LOTXLOCXID.LOC = LOC.LOC " +
            " AND LOTxLOCxID.ID = ID.ID " +
            " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
            " AND LOC.LocationFlag = 'NONE' " + 
      	   " AND LOC.Facility = N'" + dbo.fnc_RTrim(@c_facility) + "' " + 
            " AND LOTATTRIBUTE.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "' " +
            " AND LOTATTRIBUTE.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "' " +
            dbo.fnc_RTrim(@c_Condition)  + 
            " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable05 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED)   > 0  " +
            " ORDER BY LOTATTRIBUTE.Lottable05, LOT.Lot " 

      EXEC(@c_SQLStatement)
   
      -- print @c_SQLStatement

   END
END

GO