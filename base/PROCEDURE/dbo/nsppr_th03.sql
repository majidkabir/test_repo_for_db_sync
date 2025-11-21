SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPR_TH03                                         */
/* Creation Date: 02-OCT-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 353896-TH-PreAllocateStrategy : First In First Out          */
/*          Outgoing Shelflife by Sku.SUSR2 or DOCLKUP.Shelflife        */
/*          by consignee,skugroup                                       */
/*                                                                      */
/* Called By: nspOrderProcessing		                                    */
/*                                                                      */
/* PVCS Version: 1.5		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Rev  Purposes                                   */      
/************************************************************************/

CREATE PROC [dbo].[nspPR_TH03]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 DATETIME ,
@d_lottable05 DATETIME ,
@c_lottable06 NVARCHAR(30),
@c_lottable07 NVARCHAR(30),
@c_lottable08 NVARCHAR(30),
@c_lottable09 NVARCHAR(30),
@c_lottable10 NVARCHAR(30),
@c_lottable11 NVARCHAR(30),
@c_lottable12 NVARCHAR(30),
@d_lottable13 DATETIME,
@d_lottable14 DATETIME,
@d_lottable15 DATETIME,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(5),    
@n_uombase int ,
@n_qtylefttofulfill INT,
@c_OtherParms NVARCHAR(200)=''
AS
BEGIN   
   DECLARE @n_StorerMinShelfLife int,
           @c_Condition NVARCHAR(510),
           @c_SQLStatement NVARCHAR(3999) 

   DECLARE @c_Orderkey        NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_ID              NVARCHAR(18),
           @n_OutGoingShelfLife   INT,
           @n_ConsShelfLife       INT,
           @n_Shelflife           INT           
           
   SELECT  @n_StorerMinShelfLife = 0,
           @n_OutGoingShelfLife = 0,
           @n_ConsShelfLife = 0,
           @n_Shelflife = 0

   IF @n_QtyLeftToFulfill < @n_UOMBase   
   BEGIN  
        DECLARE PREALLOCATE_CURSOR_CANDIDATES  SCROLL CURSOR    
        FOR  
            SELECT LOT.StorerKey  
                  ,LOT.SKU  
                  ,LOT.LOT  
                  ,QTYAVAILABLE = 0  
            FROM   LOT(NOLOCK)   
            WHERE 1=2                
       RETURN  
   END  

   IF LEN(@c_OtherParms) > 0 
   BEGIN
   	  SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
   	  SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
   	  
   	  SELECT @c_ID = ID
   	  FROM ORDERDETAIL(NOLOCK)
   	  WHERE Orderkey = @c_Orderkey
   	  AND OrderLineNumber = @c_OrderLineNumber   	  
   END
   
   IF ISNULL(@c_lot,'') <> '' AND LEFT(LTRIM(ISNULL(@c_lot,'')),1) <> '*'
   BEGIN
      /* Get Storer Minimum Shelf Life */
      
      SELECT @n_StorerMinShelfLife = ISNULL(((Sku.Shelflife * Storer.MinShelflife/100) * -1),0)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey
      AND Sku.Facility = @c_facility  
      
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
      SELECT @n_StorerMinShelfLife = ISNULL(((Sku.Shelflife * Storer.MinShelflife/100) * -1), 0),
             @n_OutGoingShelfLife = ISNULL(CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN
                                         CAST(SKU.Susr2 AS INT)
                                     ELSE 0 END, 0) * -1
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey
      AND Sku.Facility = @c_facility 
            
      SELECT TOP 1 @n_ConsShelfLife = ISNULL(D.Shelflife,0) * -1
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      JOIN DOCLKUP D(NOLOCK) ON S.CustomerGroupCode = D.ConsigneeGroup AND SKU.SkuGroup = D.SkuGroup         
      WHERE O.Orderkey = @c_Orderkey
      AND OD.Sku = @c_Sku
      
      IF @n_ConsShelfLife <> 0
         SELECT @n_Shelflife = @n_ConsShelfLife
      ELSE IF @n_OutGoingShelfLife <> 0 
         SELECT @n_Shelflife = @n_OutGoingShelfLife       
      ELSE IF @n_StorerMinShelfLife <> 0
         SELECT @n_Shelflife = @n_StorerMinShelfLife       
      ELSE
         SELECT @n_Shelflife = 0                    
   
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
      IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_Lottable04 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_Lottable05 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable06)) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE06 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable06)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable07)) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE07 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable07)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable08)) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE08 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable08)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable09)) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE09 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable09)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable10)) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE10 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable10)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable11)) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE11 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable11)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable12)) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE12 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable12)) + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> "01/01/1900" AND @d_Lottable13 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE13 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> "01/01/1900" AND @d_Lottable14 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE14 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> "01/01/1900" AND @d_Lottable15 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE15 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + "' "
      END

      IF @n_ShelfLife <> 0 
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, " + CAST(@n_ShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() " 
      END 
              
      IF ISNULL(@c_ID,'') <> ''
      BEGIN
      	 SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTxLOCxID.Id = N'" + RTRIM(@c_ID) + "' "
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