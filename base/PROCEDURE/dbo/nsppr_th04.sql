SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPR_TH04                                         */
/* Creation Date: 02-OCT-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 353896-TH-PreAllocateStrategy : First Expired First Out     */
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

CREATE PROC [dbo].[nspPR_TH04]
   @c_storerkey NVARCHAR(15) ,
   @c_sku NVARCHAR(20) ,
   @c_lot NVARCHAR(10) ,
   @c_lottable01 NVARCHAR(18) ,
   @c_lottable02 NVARCHAR(18) ,
   @c_lottable03 NVARCHAR(18) ,
   @d_lottable04 datetime ,
   @d_lottable05 datetime ,
   @c_lottable06 NVARCHAR(30) ,   
   @c_lottable07 NVARCHAR(30) ,   
   @c_lottable08 NVARCHAR(30) ,  
   @c_lottable09 NVARCHAR(30) ,  
   @c_lottable10 NVARCHAR(30) ,  
   @c_lottable11 NVARCHAR(30) ,  
   @c_lottable12 NVARCHAR(30) ,  
   @d_lottable13 DATETIME ,      
   @d_lottable14 DATETIME ,        
   @d_lottable15 DATETIME ,      
   @c_UOM NVARCHAR(10) ,
   @c_Facility NVARCHAR(5),    
   @n_UOMBase int ,
   @n_QtyLeftToFulfill int,
   @c_OtherParms NVARCHAR(200)=''
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET NOCOUNT ON 
    
   DECLARE @n_StorerMinShelfLife INT,
           @c_Condition          NVARCHAR(4000),   
           @c_SQLStatement       NVARCHAR(3999) 
   
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
      
      SELECT @n_StorerMinShelfLife = ISNULL(((Sku.Shelflife * Storer.MinShelflife/100) * -1), 0)
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
      ORDER BY Lotattribute.Lottable04, Lot.Lot
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
      AND Sku.Facility = @c_facility  -- added By Vicky for IDSV5 
   
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
      IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE04 = N'" + ISNULL(RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)),'') + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE05 = N'" + ISNULL(RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)),'') + "' "
      END
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
      END   
      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
      END   
      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
      END   
      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable09 = N''' + RTRIM(@c_Lottable09) + '''' 
      END   
      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable10 = N''' + RTRIM(@c_Lottable10) + '''' 
      END   
      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
      END   
      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
      END  
      IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
      END
      IF @n_ShelfLife <> 0
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND DateAdd(Day, " + CAST(@n_ShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() " 
      END       
      IF ISNULL(@c_ID,'') <> ''
      BEGIN
      	 SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTxLOCxID.Id = N'" + RTRIM(@c_ID) + "' "
      END
   
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
            " AND LOC.LocationFlag = 'NONE' " +  
            " AND LOC.Facility = N'" + RTRIM(@c_facility) + "' "  +
            ISNULL(RTRIM(@c_Condition),'')  + 
            " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable04 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(ISNULL(P.QTYPREALLOCATED,0)) >= " + CAST(@n_UOMBase AS VARCHAR(10)) + 
            " ORDER BY Lotattribute.Lottable04, LOT.Lot " 

      EXEC(@c_SQLStatement)
   
      -- print @c_SQLStatement

   END
END

GO