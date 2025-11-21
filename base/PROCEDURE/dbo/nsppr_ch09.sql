SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPR_CH09                                         */
/* Creation Date: 27-May-2019                                           */
/* Copyright: LF                                                        */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose: PreAllocateStrategy : First Expired First Out               */
/*          Copy from nspPR_FEFO                                        */
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

CREATE PROC [dbo].[nspPR_CH09]
   @c_storerkey NVARCHAR(15) ,
   @c_sku NVARCHAR(20) ,
   @c_lot NVARCHAR(10) ,
   @c_lottable01 NVARCHAR(18) ,
   @c_lottable02 NVARCHAR(18) ,
   @c_lottable03 NVARCHAR(18) ,
   @d_lottable04 datetime ,
   @d_lottable05 datetime ,
   @c_lottable06 NVARCHAR(30) ,  --(CS01)  
   @c_lottable07 NVARCHAR(30) ,  --(CS01)  
   @c_lottable08 NVARCHAR(30) ,  --(CS01)
   @c_lottable09 NVARCHAR(30) ,  --(CS01)
   @c_lottable10 NVARCHAR(30) ,  --(CS01)
   @c_lottable11 NVARCHAR(30) ,  --(CS01)
   @c_lottable12 NVARCHAR(30) ,  --(CS01)
   @d_lottable13 DATETIME ,      --(CS01)
   @d_lottable14 DATETIME ,      --(CS01)   
   @d_lottable15 DATETIME ,      --(CS01)
   @c_UOM NVARCHAR(10) ,
   @c_Facility NVARCHAR(5),    -- added By Vicky for IDSV5 
   @n_UOMBase int ,
   @n_QtyLeftToFulfill int,
   @c_OtherParms NVARCHAR(200)=''
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
    SET NOCOUNT ON 
    
   DECLARE @n_StorerMinShelfLife INT,
           @c_Condition          NVARCHAR(4000),   --(CS01)
           @c_SQLStatement       NVARCHAR(3999),
           @c_SQLParm            NVARCHAR(3999) 
   
   DECLARE @c_Orderkey         NVARCHAR(10),
           @c_OrderLineNumber  NVARCHAR(5),
           @c_ID               NVARCHAR(18),
           @c_CheckSkuFacility NVARCHAR(10) --NJOW03                                 

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

   --NJOW03   
   IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK)
             WHERE ListName = 'PKCODECFG'
             AND Storerkey = @c_Storerkey
             AND Code = 'NoCheckSkuFacility'
             AND Long = 'nspPR_CH09'
             AND ISNULL(Short,'') <> 'N')
      SET @c_CheckSkuFacility = 'N'
   ELSE
      SET @c_CheckSkuFacility = 'Y'
                       
   IF ISNULL(RTRIM(@c_lot),'') <> '' -- SOS99448
   BEGIN
      /* Get Storer Minimum Shelf Life */
      
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey
      AND (Sku.Facility = @c_facility OR @c_CheckSkuFacility = 'N')  -- added By Vicky for IDSV5 
      
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (Nolock), Lotattribute (Nolock)
      WHERE LOT.LOT = @c_lot 
      AND Lot.Lot = Lotattribute.Lot 
      AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
      ORDER BY Lotattribute.Lottable04, Lotattribute.Lottable05, Lot.Lot
   END
   ELSE
   BEGIN
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey
      AND (Sku.Facility = @c_facility OR @c_CheckSkuFacility = 'N') -- added By Vicky for IDSV5 
   
      IF @n_StorerMinShelfLife IS NULL
         SELECT @n_StorerMinShelfLife = 0
   
      IF ISNULL(RTRIM(@c_Lottable01),'') <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = ISNULL(RTRIM(@c_Lottable01),'') "
      END
      IF ISNULL(RTRIM(@c_Lottable02),'') <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE02 = ISNULL(RTRIM(@c_Lottable02),'') "
      END
      IF ISNULL(RTRIM(@c_Lottable03),'') <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE03 = ISNULL(RTRIM(@c_Lottable03),'') "
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE04 = @d_Lottable04 "
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE05 = @d_Lottable05 "
      END

      --(CS01) - START
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable06 = RTRIM(@c_Lottable06) ' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable07 = RTRIM(@c_Lottable07) ' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable08 = RTRIM(@c_Lottable08) ' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable09 = RTRIM(@c_Lottable09) ' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable10 = RTRIM(@c_Lottable10) ' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable11 = RTRIM(@c_Lottable11) ' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable12 = RTRIM(@c_Lottable12) ' 
      END  

      IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable13 = @d_Lottable13 '
      END

      IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable14 = @d_Lottable14 '
      END

      IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable15 = @d_Lottable15 '
      END
      --(CS01) - END
   
      -- SOS44137
      -- IF @n_StorerMinShelfLife > 0 
      IF @n_StorerMinShelfLife <> 0
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() " 
      END 
      
      IF ISNULL(@c_ID,'') <> ''
      BEGIN
      	 SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTxLOCxID.Id = RTRIM(@c_ID) "
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
            "                JOIN   ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey AND P.OrderLineNumber = ORDERDETAIL.OrderLineNumber " +   --NJOW02
            "                WHERE  P.Storerkey = RTRIM(@c_storerkey) " +     
            "                AND    P.SKU = RTRIM(@c_SKU) " +
            "                AND    ORDERS.FACILITY = RTRIM(@c_facility) " +   
            "                AND    P.qty > 0 " +    
            CASE WHEN ISNULL(@c_ID,'') <> '' THEN " AND ORDERDETAIL.ID = RTRIM(@c_ID) " ELSE " " END +  --NJOW02
            "                GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility " +   
            " WHERE LOT.STORERKEY = RTRIM(@c_storerkey) " +   
            " AND LOT.SKU = RTRIM(@c_SKU) " +
            " AND LOT.STATUS = 'OK'  " +   
            " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' " +     
            " AND LOC.LocationFlag = 'NONE' " +  
            " AND LOC.Facility = RTRIM(@c_facility) "  +
            ISNULL(RTRIM(@c_Condition),'')  + 
            " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable04, Lotattribute.Lottable05 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(ISNULL(P.QTYPREALLOCATED,0)) >= " + CAST(@n_UOMBase AS VARCHAR(10)) + 
            " ORDER BY Lotattribute.Lottable04, Lotattribute.Lottable05, LOT.Lot " 

      SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                         '@c_ID        NVARCHAR(18),  @c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +
                         '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +
                         '@c_Lottable06 NVARCHAR(30), ' +
                         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' + 
                         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' + 
                         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +
                         '@n_StorerMinShelfLife INT '     
      
      EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU, @c_ID, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                         @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, 
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,  @n_StorerMinShelfLife   


--      EXEC(@c_SQLStatement)
   
       --print @c_SQLStatement

   END
END

GO