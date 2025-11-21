SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRFIFO3														*/
/* Creation Date: 16-Jun-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: shong                                                    */
/*                                                                      */
/* Purpose: Select LOT by FIFO in BULK Location Only          	         */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspPRFIFO3] 
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
SET CONCAT_NULL_YIELDS_NULL OFF
SET NOCOUNT ON

DECLARE @b_debug int,  
        @c_LimitString NVARCHAR(255), 
		  @c_SQL NVARCHAR(max)

  
SELECT @b_debug=0

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
    SELECT "nspPRFIFO3 : After Lot Lookup ....."  
    SELECT '@c_LOT'=@c_LOT,'@c_Lottable01'=@c_Lottable01, '@c_Lottable02'=@c_Lottable02, '@c_Lottable03'=@c_Lottable03
    SELECT '@d_Lottable04' = @d_Lottable04, '@d_Lottable05' = @d_Lottable05
    SELECT '@c_StorerKey' = @c_StorerKey
END  
   
  
IF LTrim(RTrim(@c_LOT)) IS NOT NULL AND LTrim(RTrim(@c_LOT)) <> ''
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
   SELECT @c_LimitString = ''  

   IF @c_Lottable01 <> ' '  
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND Lottable01= N'" + LTrim(RTrim(@c_Lottable01)) + "'"  
   
   IF @c_Lottable02 <> ' '  
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND Lottable02= N'" + LTrim(RTrim(@c_Lottable02)) + "'"  
   
   IF @c_Lottable03 <> ' '  
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND Lottable03= N'" + LTrim(RTrim(@c_Lottable03)) + "'"    		
   
   IF @d_Lottable04 IS NOT NULL AND @d_Lottable04 <> '1900-01-01'
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND Lottable04 = N'" + LTrim(RTrim(CONVERT(char(20), @d_Lottable04))) + "'"  
  
   IF @d_Lottable05 IS NOT NULL  AND @d_Lottable05 <> '1900-01-01'
      SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND Lottable05= N'" + LTrim(RTrim(CONVERT(char(20), @d_Lottable05))) + "'"  

   IF @b_debug = 1
   BEGIN
     SELECT 'c_LimitString', @c_LimitString
   END

	SELECT @c_SQL = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +  
		" SELECT LOT.STORERKEY , LOT.SKU, LOT.LOT," +  
		" QTYAVAILABLE = ( SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) " +
		" FROM LOT (NOLOCK) " +  
		" INNER JOIN LOTxLOCxID (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT " + 
		" INNER JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC " + 
		" INNER JOIN SKUxLOC (NOLOCK) ON SKUxLOC.STORERKEY = LOTxLOCxID.STORERKEY AND SKUxLOC.SKU = LOTxLOCxID.SKU " + 
      " AND SKUxLOC.LOC = LOTxLOCxID.LOC " + 
		" INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
		" LEFT OUTER JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
		" LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +
		"				  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " + 
		"				  WHERE  p.Orderkey = ORDERS.Orderkey " +
		"				  AND    p.SKU = N'" + RTrim(@c_SKU) + "'" + 
		"				  AND    p.StorerKey = N'" + RTrim(@c_StorerKey) + "'" + 
      "             AND    p.Qty > 0 " + 
		"				  GROUP BY p.Lot, ORDERS.Facility) As P ON LOTxLOCxID.Lot = P.Lot AND LOC.Facility = P.Facility " +
		" WHERE LOTxLOCxID.STORERKEY = N'" + RTrim(@c_StorerKey) + "'" + 
		" AND LOTxLOCxID.SKU = N'" + RTrim(@c_SKU) + "' " +  
		" AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +  
		" AND LOC.FACILITY = N'" + RTrim(@c_Facility) + "'"  + 
      " AND LOTATTRIBUTE.STORERKEY = N'" + RTrim(@c_StorerKey) + "'" + 
		" AND LOTATTRIBUTE.SKU = N'" + RTrim(@c_SKU) + "' " +  
      " AND SKUxLOC.LocationType NOT IN ('CASE','PICK') " + 
      RTrim(@c_LimitString) + " " +   
		" GROUP BY LOT.STORERKEY ,LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " + 
		" HAVING (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QTYPicked)- MIN(ISNULL(P.QtyPreAllocated, 0))) > 0 " +
      " ORDER BY LOTATTRIBUTE.Lottable05, LOT.Lot "

   EXEC (@c_SQL)   

	IF @b_debug = 1 SELECT @c_SQL				
END

GO