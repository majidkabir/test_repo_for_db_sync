SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRFIFO2                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: nspPrealLOCateOrderProcessing                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 02-Jan-2020 Wan01    1.1   Dynamic SQL review, impact SQL cache log  */  
/************************************************************************/

-- PGD TH Preallocation Strategy 
CREATE PROC [dbo].[nspPRFIFO2] 
    @c_StorerKey NVARCHAR(15) ,  
    @c_SKU NVARCHAR(20) ,  
    @c_LOT NVARCHAR(10) ,  
    @c_Lottable01 NVARCHAR(18) ,  
    @c_Lottable02 NVARCHAR(18) ,  
    @c_Lottable03 NVARCHAR(18) ,  
    @d_Lottable04 datetime ,  
    @d_Lottable05 datetime ,  
    @c_UOM NVARCHAR(10) ,
    @c_Facility NVARCHAR(10)  ,
    @n_UOMBase int ,  
    @n_QtyLeftToFulfill int  -- new column
AS

DECLARE @b_debug int,  
        @c_Manual NVARCHAR(1),
        @c_LimitString NVARCHAR(255), 
	     @n_ShelfLife int,
		  @c_SQL NVARCHAR(max)
   
DECLARE @c_Lottable04Label NVARCHAR(20),
        @c_SortOrder       NVARCHAR(255)

DECLARE @c_SQLParms  NVARCHAR(4000) = ''  --(Wan01) 


SELECT @b_debug=0, @c_Manual = 'N'  

If @d_Lottable04 = '1900-01-01'
Begin
    SELECT @d_Lottable04 = null
End

If @d_Lottable05 = '1900-01-01'
Begin
	SELECT @d_Lottable05 = null
End

IF @b_debug = 1  
BEGIN  
    SELECT "nspPRFIFO2 : Before Lot Lookup ....."  
    SELECT '@c_LOT'=@c_LOT,'@c_Lottable01'=@c_Lottable01, '@c_Lottable02'=@c_Lottable02, '@c_Lottable03'=@c_Lottable03   
    SELECT '@d_Lottable04' = @d_Lottable04, '@d_Lottable05' = @d_Lottable05, '@c_Manual' = @c_Manual  , '@c_SKU' = @c_SKU
    SELECT '@c_StorerKey' = @c_StorerKey, '@c_Facility' = @c_Facility
END  
     
-- when any of the Lottables is supplied, get the specific lot  
IF (@c_Lottable01 <> '' OR 
    @c_Lottable02 <> '' OR 
    @c_Lottable03 <> '' OR   
    @d_Lottable04 IS NOT NULL OR 
    @d_Lottable05 IS NOT NULL) OR LEFT(@c_LOT,1) = '*'
BEGIN  
     SELECT @c_Manual = 'N'  
END  
  
IF @b_debug = 1  
BEGIN  
    SELECT "nspPRFIFO2 : After Lot Lookup ....."  
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
      
      IF @d_Lottable04 IS NOT NULL AND @d_Lottable04 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 = @d_Lottable04"  
      
      IF @d_Lottable05 IS NOT NULL  AND @d_Lottable05 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable05= @d_Lottable05"  


      SELECT @n_ShelfLife = CASE WHEN ISNUMERIC(SUSR2) = 1 Then CAST(SUSR2 as int) 
                                ELSE 0
                                END, 
            @c_Lottable04Label = Lottable04Label 
      FROM 	SKU (NOLOCK)
      WHERE SKU = @c_SKU
      AND   STORERKEY = @c_StorerKey
      
      SELECT @c_SortOrder = " ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot"      

		-- Min Shelf Life Checking
      IF dbo.fnc_RTrim(@c_Lottable04Label) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable04Label) <> '' 
      BEGIN
			SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + " AND Lottable04 > CONVERT( NVARCHAR(8), DateAdd(day, @n_ShelfLife, GETDATE()), 112) "
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
			" LEFT OUTER JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
			" LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +
			"				  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " + 
			"				  WHERE  p.Orderkey = ORDERS.Orderkey " +
			"				  AND    p.SKU = @c_SKU" + 
			"				  AND    p.StorerKey = @c_StorerKey" + 
         "             AND    p.Qty > 0 " + 
			"				  GROUP BY p.Lot, ORDERS.Facility) As P ON LOTxLOCxID.Lot = P.Lot AND LOC.Facility = P.Facility " +
			" WHERE LOTxLOCxID.STORERKEY = @c_StorerKey AND LOTxLOCxID.SKU = @c_SKU " +  
			" AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +  
			" AND LOC.FACILITY = @c_Facility"  + 
         " AND LOTATTRIBUTE.STORERKEY = @c_StorerKey AND LOTATTRIBUTE.SKU = @c_SKU " +  
         dbo.fnc_RTrim(@c_LimitString) + " " +   
			" GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " + 
			" HAVING (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QTYPicked)- MIN(ISNULL(P.QtyPreAllocated, 0))) > 0 " +
			@c_SortOrder

      --Wan01 - START 
      --EXEC (@c_SQL)   
      SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
               + ',@c_storerkey  NVARCHAR(15)'
               + ',@c_SKU        NVARCHAR(20)'
               + ',@c_Lottable01 NVARCHAR(18)'
               + ',@c_Lottable02 NVARCHAR(18)'
               + ',@c_Lottable03 NVARCHAR(18)'
               + ',@d_lottable04 datetime'
               + ',@d_lottable05 datetime'
               + ',@n_ShelfLife  int'
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParms, @c_facility, @c_Storerkey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                        ,@n_ShelfLife 
      --Wan01 - END 
		IF @b_debug = 1 SELECT @c_SQL				
   END
END

GO