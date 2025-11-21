SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPRLEVQ2                                         */
/* Creation Date: 25-Nov-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#196753                                                  */   
/*                                                                      */
/* Called By: Load Plan                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/* 02-Jun-2014  TLTING   1.1  SQL2012 - Change *= to Left Join          */ 
/* 17-Sep-2019  TLTING01 1.2  Dynamic SQL Cache recompile               */
/************************************************************************/

CREATE PROC [dbo].[nspPRLEVQ2]
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
@n_qtylefttofulfill int
AS
BEGIN
   
   DECLARE @n_StorerMinShelfLife int,
           @c_Condition NVARCHAR(510),
           @c_SQLStatement NVARCHAR(3999),
           @c_SQLParm      NVARCHAR(4000)   

   SELECT @c_SQLStatement = '', @c_SQLParm = ''
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      /* Get Storer Minimum Shelf Life */
      
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey
      AND Sku.Facility = @c_facility  -- added By Vicky for IDSV5 
      
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
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
         SELECT @c_Condition = " AND LOTTABLE01 = @c_Lottable01 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = @c_Lottable02 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = @c_Lottable03 "
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = @d_Lottable04 "
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = @d_Lottable05 "
      END
   
      IF @n_StorerMinShelfLife > 0 
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() " 
      END 
      
     SELECT @c_SQLStatement =  " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
            " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(ISNULL(PREALLOC.QTYPREALLOCATED,0)) )  " +            
            " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK) " +
            "      LEFT JOIN (SELECT LOT, SUM(Qty) AS QTYPREALLOCATED FROM PREALLOCATEPICKDETAIL (NOLOCK) " + 
            "       WHERE PreAllocatePickCode = 'nspPRLEVQ2' AND Storerkey = @c_storerkey " +
            "       AND SKU = @c_SKU GROUP BY LOT) PREALLOC ON ( PREALLOC.LOT = LOT.LOT )  " +
            ", LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)   " + 
            " WHERE LOT.STORERKEY = @c_storerkey " +
            " AND LOT.SKU = @c_SKU " +
            " AND LOT.STATUS = 'OK' " +
            " AND LOT.LOT = LOTATTRIBUTE.LOT " +
      	   " AND LOTXLOCXID.Lot = LOT.LOT " +
      	   " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +
      	   " AND LOTXLOCXID.LOC = LOC.LOC " +
            " AND LOTxLOCxID.ID = ID.ID " +
            " AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey " +
            " AND LOTxLOCxID.SKU = SKUxLOC.SKU " +
            " AND LOTxLOCxID.Loc = SKUxLOC.Loc " +
            " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
            " AND LOC.LocationFlag = 'NONE' " + 
      	   " AND LOC.Facility = @c_facility " + 
 --           " AND LOTATTRIBUTE.STORERKEY = '" + dbo.fnc_RTrim(@c_storerkey) + "' " +
--            " AND LOTATTRIBUTE.SKU = '" + dbo.fnc_RTrim(@c_SKU) + "' " +
            " AND LOC.Loclevel <> 1 " +
            dbo.fnc_RTrim(@c_Condition)  + 
            " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable05 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(ISNULL(PREALLOC.QTYPREALLOCATED,0)) > 0  " +
            " ORDER BY MIN(SKUxLOC.QTY - SKUxLOC.QTYALLOCATED - SKUxLOC.QTYPICKED), MIN(LOC.LogicalLocation), MIN(LOC.Loc) " 

         SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +   
            '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +
               '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +
            '@n_StorerMinShelfLife INT  '     
      
         EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU,  @c_Lottable01, @c_Lottable02, @c_Lottable03,
                         @d_Lottable04, @d_Lottable05, @n_StorerMinShelfLife  

--      EXEC(@c_SQLStatement)
   
      -- print @c_SQLStatement

   END
END

GO