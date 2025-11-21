SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: nspPR_KR01                                         */      
/* Creation Date: 07-APR-2021                                           */      
/* Copyright: LFL                                                       */      
/* Written by: WMS-16770 Korea AOS allocation location priority         */
/*             by putawayzone.zonecategory. (copy from nspPRFEFO2)      */                                                               
/*                                                                      */      
/* Purpose:                                                             */
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.6                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Ver   Purposes                                  */  
/************************************************************************/      

-- PGD TH Preallocation Strategy 
CREATE PROC [dbo].[nspPR_KR01] 
    @c_StorerKey NVARCHAR(15) ,  
    @c_SKU NVARCHAR(20) ,  
    @c_LOT NVARCHAR(10) ,  
    @c_Lottable01 NVARCHAR(18) ,  
    @c_Lottable02 NVARCHAR(18) ,  
    @c_Lottable03 NVARCHAR(18) ,  
    @d_Lottable04 datetime ,  
    @d_Lottable05 datetime ,
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
    @c_Facility NVARCHAR(10)  ,
    @n_UOMBase int ,  
    @n_QtyLeftToFulfill int  
   ,@c_OtherParms NVARCHAR(200)=''
AS  

DECLARE @b_debug int,  
        @c_Manual NVARCHAR(1),
        @c_LimitString NVARCHAR(4000),  
        @n_ShelfLife int,
        @c_SQL NVARCHAR(max)
   
DECLARE @c_Lottable04Label NVARCHAR(20),
        @c_SortOrder       NVARCHAR(255),
        @n_ConMinShelfLife INT, 
        @c_Orderkey        NVARCHAR(10), 
        @c_Strategykey     NVARCHAR(10), 
        @n_SkuGroupShelfLife INT, 
        @n_SkuGroupShelfLife2 INT        

DECLARE @c_SQLParms        NVARCHAR(4000) = ''  

SELECT @c_Orderkey = LEFT(@c_OtherParms,10) 

SELECT @b_debug=0, @c_Manual = 'N'  

If @d_Lottable04 = '1900-01-01'
Begin
    SELECT @d_Lottable04 = null
End

If @d_Lottable05 = '1900-01-01'
Begin
   SELECT @d_Lottable05 = null
End

IF @d_lottable13 = '1900-01-01'
BEGIN
   SET @d_lottable13 = NULL
END

IF @d_lottable14 = '1900-01-01'
BEGIN
   SET @d_lottable14 = NULL
END

IF @d_lottable15 = '1900-01-01'
BEGIN
   SET @d_lottable15 = NULL
End

IF @b_debug = 1  
BEGIN  
    SELECT "nspPR_KR01 : Before Lot Lookup ....."  
    SELECT '@c_LOT'=@c_LOT,'@c_Lottable01'=@c_Lottable01, '@c_Lottable02'=@c_Lottable02, '@c_Lottable03'=@c_Lottable03   
    SELECT '@d_Lottable04' = @d_Lottable04, '@d_Lottable05' = @d_Lottable05, '@c_Manual' = @c_Manual  , '@c_SKU' = @c_SKU
    SELECT '@c_StorerKey' = @c_StorerKey, '@c_Facility' = @c_Facility
END  
     
-- when any of the Lottables is supplied, get the specific lot  
IF (@c_Lottable01 <> '' OR 
    @c_Lottable02 <> '' OR 
    @c_Lottable03 <> '' OR   
    @d_Lottable04 IS NOT NULL OR 
    @d_Lottable05 IS NOT NULL  
   OR @c_lottable06 <> '' 
   OR @c_lottable07 <> '' 
   OR @c_lottable08 <> '' 
   OR @c_lottable09 <> '' 
   OR @c_lottable10 <> ''
   OR @c_lottable11 <> '' 
   OR @c_lottable12 <> ''
   OR @d_lottable13 IS NOT NULL 
   OR @d_lottable14 IS NOT NULL 
   OR @d_lottable15 IS NOT NULL
    ) OR LEFT(@c_LOT,1) = '*'
BEGIN  
     SELECT @c_Manual = 'N'  
END  
  
IF @b_debug = 1  
BEGIN  
    SELECT "nspPR_KR01 : After Lot Lookup ....."  
    SELECT '@c_LOT'=@c_LOT,'@c_Lottable01'=@c_Lottable01, '@c_Lottable02'=@c_Lottable02, '@c_Lottable03'=@c_Lottable03
    SELECT '@d_Lottable04' = @d_Lottable04, '@d_Lottable05' = @d_Lottable05, '@c_Manual' = @c_Manual  
    SELECT '@c_StorerKey' = @c_StorerKey
END  
     
IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) IS NOT NULL AND LEFT(@c_LOT, 1) <> '*'
BEGIN       
   /* Lot specific candidate set */  
   DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT LOT.STORERKEY, 
          LOT.SKU, 
          LOT.LOT,  
          QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) 
   FROM  LOT (NOLOCK) 
   INNER JOIN LOTxLOCxID (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT
   INNER JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
   INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT    
   LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty)
                    FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)
                    WHERE  p.Orderkey = ORDERS.Orderkey
                    GROUP BY p.Lot, ORDERS.Facility) As P ON LOTxLOCxID.Lot = P.Lot AND LOC.Facility = P.Facility
   WHERE LOC.Facility = @c_Facility
   AND   LOT.LOT = @c_LOT  
   GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05
END  
ELSE 
BEGIN            
   /* Everything Else when no Lottable supplied */  
   IF @c_Manual = 'N'   
   BEGIN     	
      SELECT @c_LimitString = ''  
   
      IF @c_Lottable01 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= @c_Lottable01" 
      
      IF @c_Lottable02 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable02= @c_Lottable02" 
      
      IF @c_Lottable03 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable03= @c_Lottable03" 
      ELSE IF @c_Storerkey = 'PRESTIGE'  
      BEGIN
         SET @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND Lottable03 = ''OK'' '         
      END

      IF @d_Lottable04 IS NOT NULL AND @d_Lottable04 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 = @d_Lottable04"
      
      IF @d_Lottable05 IS NOT NULL  AND @d_Lottable05 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable05 = @d_Lottable05"

      --(Wan01) - START
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable06 = @c_Lottable06' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable07 = @c_Lottable07' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable08 = @c_Lottable08' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable09 = @c_Lottable09' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable10 = @c_Lottable10' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable11 = @c_Lottable11' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable12 = @c_Lottable12' 
      END  

      IF @d_Lottable13 <> '1900-01-01' AND @d_Lottable13 IS NOT NULL 
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable13 = @d_Lottable13'
      END

      IF @d_Lottable14 <> '1900-01-01' AND @d_Lottable14 IS NOT NULL 
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable14 = @d_Lottable14'
      END

      IF @d_Lottable15 <> '1900-01-01' AND @d_Lottable15 IS NOT NULL
      BEGIN
         SET @c_LimitString = @c_LimitString + ' AND Lottable15 = @d_Lottable15'
      END
      --(Wan01) - END

      SELECT @n_ShelfLife = CASE WHEN ISNUMERIC(SUSR2) = 1 Then CAST(SUSR2 as int) 
                                ELSE 0
                                END, 
            @c_Lottable04Label = Lottable04Label,
            @c_Strategykey = Strategykey 
      FROM  SKU (NOLOCK)
      WHERE SKU = @c_SKU
      AND   STORERKEY = @c_StorerKey
      
      SELECT @c_SortOrder = " ORDER BY PUTAWAYZONE.ZoneCategory, LOTATTRIBUTE.Lottable04, LOT.Lot"      
      
          	SELECT TOP 1 @n_ConMinShelfLife = S.MinShelflife,
    	             @n_SkuGroupShelfLife = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT) ELSE 0 END, 
    	             @n_SkuGroupShelfLife2 = CASE WHEN ISNUMERIC(CL2.Short) = 1 THEN CAST(CL2.Short AS INT) ELSE 0 END 
      FROM ORDERS O (NOLOCK)
      JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey
      JOIN SKU (NOLOCK) ON SKU.Storerkey = @c_Storerkey AND SKU.Sku = @c_Sku
      LEFT JOIN CODELKUP CL (NOLOCK) ON (O.Storerkey = CL.Storerkey AND SKU.Busr6 = CL.Code AND SKU.SkuGroup = CL.Code2 AND CL.Listname = 'PRESTALLOC'
                                      AND (S.Secondary = CL.UDF01 OR S.Secondary = CL.UDF02 OR S.Secondary = CL.UDF03 OR S.Secondary = CL.UDF04 OR S.Secondary = CL.UDF05)) 
      OUTER APPLY (SELECT TOP 1 CL3.Short FROM CODELKUP CL3 (NOLOCK) WHERE O.Storerkey = CL3.Storerkey AND SKU.Busr6 <> CL3.Code AND SKU.SkuGroup <> CL3.Code2 AND CL3.Listname = 'PRESTALLOC' AND CL3.Code = 'ALLOTHERS'
                   AND (S.Secondary = CL3.UDF01 OR S.Secondary = CL3.UDF02 OR S.Secondary = CL3.UDF03 OR S.Secondary = CL3.UDF04 OR S.Secondary = CL3.UDF05)) CL2        
      WHERE O.Orderkey = @c_Orderkey

      IF @c_Strategykey = 'PPDFEFO' AND ISNULL(@n_SkuGroupShelfLife,0) > 0
      BEGIN
         SET @c_LimitString = dbo.fnc_RTrim(@c_LimitString) +  " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable04) >= @n_SkuGroupShelfLife "              	
      END
      ELSE IF  @c_Strategykey = 'PPDFEFO' AND ISNULL(@n_SkuGroupShelfLife2,0) > 0
      BEGIN
         SET @c_LimitString = dbo.fnc_RTrim(@c_LimitString) +  " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable04) >= @n_SkuGroupShelfLife2 "              	
      END      
      ELSE IF @c_Strategykey = 'PPDFEFO' AND ISNULL(@n_ConMinShelfLife,0) > 0
      BEGIN
      	 --NJOW01
         --SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 > N'"  + CONVERT( NVARCHAR(8), DateAdd(day, @n_ConMinShelfLife, GETDATE()), 112) + "'"      	       	      	 
         SET @c_LimitString = dbo.fnc_RTrim(@c_LimitString) +  " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable04) >= @n_ConMinShelfLife " 
      END
      ELSE IF @c_Strategykey = 'PPDFEFO' AND ISNULL(@n_ShelfLife,0) > 0        
      BEGIN
         SET @c_LimitString = dbo.fnc_RTrim(@c_LimitString) +  " AND DateDiff(Day, GETDATE(), LOTATTRIBUTE.Lottable04) >= @n_ShelfLife "  
      END
      ELSE IF dbo.fnc_RTrim(@c_Lottable04Label) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable04Label) <> '' 
      BEGIN
         -- Min Shelf Life Checking
         SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 > CONVERT( NVARCHAR(8), DateAdd(day, @n_ShelfLife, GETDATE()), 112)"  
     END 

      IF @b_debug = 1
      BEGIN
        SELECT 'c_LimitString', @c_LimitString
      END

      SELECT @c_SQL = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +  
         " SELECT MIN(LOTxLOCxID.STORERKEY) , MIN(LOTxLOCxID.SKU), LOT.LOT," +  
         " QTYAVAILABLE = ( SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) " +
         " FROM LOT (NOLOCK) " +  
         " INNER JOIN LOTxLOCxID (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT " + 
         " INNER JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC " + 
         " INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
         " LEFT JOIN PUTAWAYZONE WITH (NOLOCK) ON LOC.Putawayzone = PUTAWAYZONE.Putawayzone " +                               
         " LEFT OUTER JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
         " LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +
         "             FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " + 
         "             WHERE  p.Orderkey = ORDERS.Orderkey " +
         "             AND    p.SKU = @c_SKU" +                
         "             AND    p.StorerKey = @c_StorerKey" +    
         "             AND    p.Qty > 0 " + 
         "             GROUP BY p.Lot, ORDERS.Facility) As P ON LOTxLOCxID.Lot = P.Lot AND LOC.Facility = P.Facility " +
         " WHERE LOTxLOCxID.STORERKEY = @c_StorerKey AND LOTxLOCxID.SKU = @c_SKU " +                  
         " AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +  
         " AND LOC.FACILITY = @c_Facility"  +                                                
         " AND LOTATTRIBUTE.STORERKEY = @c_StorerKey AND LOTATTRIBUTE.SKU = @c_SKU " + 
         dbo.fnc_RTrim(@c_LimitString) + " " +   
         " GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05, PUTAWAYZONE.ZoneCategory " + 
         " HAVING (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QTYPicked)- MIN(ISNULL(P.QtyPreAllocated, 0))) > 0 " +
         @c_SortOrder
     
      --EXEC (@c_SQL)
      SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                     + ',@c_storerkey  NVARCHAR(15)'
                     + ',@c_SKU        NVARCHAR(20)'
                     + ',@c_Lottable01 NVARCHAR(18)'
                     + ',@c_Lottable02 NVARCHAR(18)'
                     + ',@c_Lottable03 NVARCHAR(18)'
                     + ',@d_lottable04 datetime'
                     + ',@d_lottable05 datetime'
                     + ',@c_Lottable06 NVARCHAR(30)'
                     + ',@c_Lottable07 NVARCHAR(30)'
                     + ',@c_Lottable08 NVARCHAR(30)'
                     + ',@c_Lottable09 NVARCHAR(30)'
                     + ',@c_Lottable10 NVARCHAR(30)'
                     + ',@c_Lottable11 NVARCHAR(30)'
                     + ',@c_Lottable12 NVARCHAR(30)'
                     + ',@d_lottable13 datetime'
                     + ',@d_lottable14 datetime'
                     + ',@d_lottable15 datetime'
                     + ',@n_ConMinShelfLife   int'
                     + ',@n_ShelfLife         int'
                     + ',@n_SkuGroupShelfLife int'                                                  
                     + ',@n_SkuGroupShelfLife2 int'                                                  
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                        ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                        ,@n_ConMinShelfLife,@n_ShelfLife,@n_SkuGroupShelfLife,@n_SkuGroupShelfLife2                           

      IF @b_debug = 1 SELECT @c_SQL          
   END
END

GO