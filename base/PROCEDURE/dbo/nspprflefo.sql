SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRFLEFO                                         */
/* Creation Date: 24-Mar-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 335977-First Expiry First Out / Last Expiry First Out by    */
/*          consignee SUSR1                                             */
/*                                                                      */
/* Called By: nspOrderProcessing                                        */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.   Purposes                                 */
/* 14-Apr-2015  NJOW01  1.0    fix LOC.LocationFlag <> 'HOLD'           */
/* 18-AUG-2015  YTWan   1.1    SOS#350432 - Project Merlion -           */
/*                             AllocationStrategy (Wan01)               */ 
/************************************************************************/

CREATE PROC [dbo].[nspPRFLEFO]
   @c_storerkey NVARCHAR(15) ,
   @c_sku NVARCHAR(20) ,
   @c_lot NVARCHAR(10) ,
   @c_lottable01 NVARCHAR(18) ,
   @c_lottable02 NVARCHAR(18) ,
   @c_lottable03 NVARCHAR(18) ,
   @d_lottable04 datetime ,
   @d_lottable05 datetime ,
   @c_lottable06 NVARCHAR(30) ,  --(Wan01)  
   @c_lottable07 NVARCHAR(30) ,  --(Wan01)  
   @c_lottable08 NVARCHAR(30) ,  --(Wan01)
   @c_lottable09 NVARCHAR(30) ,  --(Wan01)
   @c_lottable10 NVARCHAR(30) ,  --(Wan01)
   @c_lottable11 NVARCHAR(30) ,  --(Wan01)
   @c_lottable12 NVARCHAR(30) ,  --(Wan01)
   @d_lottable13 DATETIME ,      --(Wan01)
   @d_lottable14 DATETIME ,      --(Wan01)   
   @d_lottable15 DATETIME ,      --(Wan01) 
   @c_UOM NVARCHAR(10) ,
   @c_Facility NVARCHAR(5),    -- added By Vicky for IDSV5 
   @n_UOMBase int ,
   @n_QtyLeftToFulfill int,
   @c_OtherParms NVARCHAR(200)   
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET NOCOUNT ON 
    
   DECLARE @n_StorerMinShelfLife INT,
           @c_Condition          NVARCHAR(4000), -- (Wan01)
           @c_SQLStatement       NVARCHAR(3999), 
           @c_OrderKey           NVARCHAR(10),
           @c_OrderLineNumber    NVARCHAR(5),
           @c_Susr1              NVARCHAR(20),
           @c_Sortby             NVARCHAR(1000)

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
       
   IF ISNULL(RTRIM(@c_lot),'') <> '' -- SOS99448
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
      ORDER BY Lotattribute.Lottable04, Lot.Lot

   END
   ELSE
   BEGIN
      IF ISNULL(@c_OtherParms,'') <> ''  --when storerconfig 'Orderinfo4PreAllocation' is turned on 
      BEGIN
         SELECT @c_OrderKey = LEFT(dbo.fnc_LTrim(@c_OtherParms), 10)
         SELECT @c_OrderLineNumber = SUBSTRING(dbo.fnc_LTrim(@c_OtherParms), 11, 5)
      END

      SELECT @c_Susr1 = ISNULL(STORER.Susr1,'') 
      FROM   ORDERS (NOLOCK) 
      JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
      WHERE ORDERS.OrderKey = @c_OrderKey  
      
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey
      AND Sku.Facility = @c_facility  -- added By Vicky for IDSV5 
   
      IF @n_StorerMinShelfLife IS NULL
         SELECT @n_StorerMinShelfLife = 0
   
      IF ISNULL(RTRIM(@c_Lottable01),'') <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = N'" + ISNULL(RTRIM(@c_Lottable01),'') + "' "
      END
      IF ISNULL(RTRIM(@c_Lottable02),'') <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE02 = N'" + ISNULL(RTRIM(@c_Lottable02),'') + "' "
      END
      IF ISNULL(RTRIM(@c_Lottable03),'') <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE03 = N'" + ISNULL(RTRIM(@c_Lottable03),'') + "' "
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE04 = N'" + ISNULL(RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)),'') + "' "
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE05 = N'" + ISNULL(RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)),'') + "' "
      END
      
      --(Wan01) - START
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable09 = N''' + RTRIM(@c_Lottable09) + '''' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable10 = N''' + RTRIM(@c_Lottable10) + '''' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
      END  

      IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
      END

      IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
      END

      IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
      END
      --(Wan01) - END

      IF @n_StorerMinShelfLife <> 0
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() " 
      END 
      
      IF @c_Susr1 = 'LEFO' 
         SET @c_Sortby = ' ORDER BY Lotattribute.Lottable04 DESC, LOT.Lot '
      ELSE
         SET @c_Sortby = ' ORDER BY Lotattribute.Lottable04, LOT.Lot '                  
   
      SELECT @c_SQLStatement =  " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
            " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(ISNULL(P.QTYPREALLOCATED,0)) )  " +
            " FROM LOT WITH (NOLOCK) " +
            " JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.lot = LOTATTRIBUTE.lot) " +   
            " JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) " +    
            " JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) " +    
            " JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) " +        
            " LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +    
            "                FROM   PreallocatePickdetail P (NOLOCK) " +
            "                JOIN   ORDERS (NOLOCK) ON P.Orderkey = ORDERS.Orderkey " +    
            "                WHERE  P.Storerkey = N'" + RTRIM(@c_storerkey) + "' " +     
            "                AND    P.SKU = N'" + RTRIM(@c_SKU) + "' " +
            "                AND    ORDERS.FACILITY = N'" + RTRIM(@c_facility) + "' " +   
            "                AND    P.qty > 0 " +    
            "                GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility " +   
            " WHERE LOT.STORERKEY = N'" + RTRIM(@c_storerkey) + "' " +   
            " AND LOT.SKU = N'" + RTRIM(@c_SKU) + "' " +
            " AND LOT.STATUS = 'OK'  " +   
            " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' " +     
            " AND LOC.LocationFlag <> 'HOLD' " +  
            " AND LOC.Facility = N'" + RTRIM(@c_facility) + "' "  +
            ISNULL(RTRIM(@c_Condition),'')  + 
            " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable04 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(ISNULL(P.QTYPREALLOCATED,0)) >= " + CAST(@n_UOMBase AS VARCHAR(10)) + 
            @c_Sortby 
            --" ORDER BY Lotattribute.Lottable04, LOT.Lot " 

      EXEC(@c_SQLStatement)
   
      -- print @c_SQLStatement

   END
END

GO