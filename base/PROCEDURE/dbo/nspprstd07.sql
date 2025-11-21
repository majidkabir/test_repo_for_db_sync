SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

-- PGD TH Preallocation Strategy 
CREATE PROC [dbo].[nspPRSTD07] 
    @c_storerkey NVARCHAR(15) ,  
    @c_sku NVARCHAR(20) ,  
    @c_lot NVARCHAR(10) ,  
    @c_lottable01 NVARCHAR(18) ,  
    @c_lottable02 NVARCHAR(18) ,  
    @c_lottable03 NVARCHAR(18) ,  
    @d_lottable04 datetime ,  
    @d_lottable05 datetime ,  
    @c_uom NVARCHAR(10) ,
    @c_facility NVARCHAR(10)  ,
    @n_uombase int ,  
    @n_qtylefttofulfill int  -- new column
AS  
DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int,  
        @c_manual NVARCHAR(1),
        @c_LimitString NVARCHAR(255), 
	     @n_shelflife int,
		  @c_sql NVARCHAR(max)
   
DECLARE @c_Lottable04Label NVARCHAR(20),
        @c_SortOrder       NVARCHAR(255)
DECLARE @c_UOMBase NVARCHAR(10)

SELECT @b_success=0, @n_err=0, @c_errmsg="",@b_debug=0, @c_manual = 'N'  

SELECT @c_UOMBase = @n_uombase
     
If @d_lottable04 = '1900-01-01'
Begin
    Select @d_lottable04 = null
End

If @d_lottable05 = '1900-01-01'
Begin
	Select @d_lottable05 = null
End

IF @b_debug = 1  
BEGIN  
    SELECT "nspPRSTD07 : Before Lot Lookup ....."  
    SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03   
    SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  , '@c_sku' = @c_sku
    SELECT '@c_storerkey' = @c_storerkey, '@c_facility' = @c_facility
END  
     
-- when any of the lottables is supplied, get the specific lot  
IF (@c_lottable01<>'' OR @c_lottable02<>'' OR @c_lottable03<>'' OR   
    @d_lottable04 IS NOT NULL OR @d_lottable05 IS NOT NULL) OR LEFT(@c_lot,1) = '*'
BEGIN  
     select @c_manual = 'N'  
END  
  
IF @b_debug = 1  
BEGIN  
    SELECT "nspPRSTD07 : After Lot Lookup ....."  
    SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03
    SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  
    SELECT '@c_storerkey' = @c_storerkey
END  
   
  
IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(@c_lot, 1) <> '*'
BEGIN       
	/* Lot specific candidate set */  
	DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
	SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,  
			QTYAVAILABLE = CASE WHEN  SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) <  @n_UOMBase 
										THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) 
										WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) % @n_UOMBase = 0 
										THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) 
								ELSE
									SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) 
									-  SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) % @n_UOMBase 
								END 
	FROM  LOT
	INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT
	INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
	INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT		
	LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty)
						  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)
						  WHERE  p.Orderkey = ORDERS.Orderkey
						  GROUP BY p.Lot, ORDERS.Facility) As P ON LOTXLOCXID.Lot = P.Lot AND LOC.Facility = P.Facility
	WHERE LOC.Facility = @c_facility
	AND   LOT.LOT = @c_lot  
	GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05
	ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05

	IF @b_debug = 1
	BEGIN
		SELECT ' Lot not null'	
		SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,  
				QTYAVAILABLE = CASE WHEN  SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) <  @n_UOMBase 
											THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) 
											WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) % @n_UOMBase = 0 
											THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) 
									ELSE
										SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) 
										-  SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) % @n_UOMBase 
									END 
		FROM  LOT
		INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT
		INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
		INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT		
		LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty)
							  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)
							  WHERE  p.Orderkey = ORDERS.Orderkey
							  GROUP BY p.Lot, ORDERS.Facility) As P ON LOTXLOCXID.Lot = P.Lot AND LOC.Facility = P.Facility
		WHERE LOC.Facility = @c_facility
		AND   LOT.LOT = @c_lot  
		GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05
		ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05
	END
END  
ELSE 
BEGIN            
   /* Everything Else when no lottable supplied */  
   IF @c_manual = 'N'   
   BEGIN  
      SELECT @c_LimitString = ''  
   
      IF @c_lottable01 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)) + "'"  
      
      IF @c_lottable02 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable02= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable02)) + "'"  
      
      IF @c_lottable03 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)) + "'"    
      
      IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable04 = N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable04))) + "'"  
      
      IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable05= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable05))) + "'"  

   
      SELECT @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, '') 
      FROM 	SKU (NOLOCK)
      WHERE SKU = @c_sku
      AND   STORERKEY = @c_storerkey
      
      SELECT @c_SortOrder = ''
      IF @c_Lottable04Label <> ''
      BEGIN
         SELECT @c_SortOrder = " ORDER BY lotATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05 "
      END
      ELSE
      BEGIN
         SELECT @c_SortOrder = " ORDER BY LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05 "

		END
      
		-- Min Shelf Life Checking
      IF dbo.fnc_RTrim(@c_Lottable04Label) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable04Label) <> '' 
      BEGIN
         IF LEFT(@c_lot,1) = '*'
         BEGIN
            SELECT @n_shelflife = CONVERT(int, SUBSTRING(@c_lot, 2, 9))
            IF @n_shelflife < 13  -- it's month
            BEGIN
                SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(8),Lottable04, 112) >= N'"  + convert(char(8), DateAdd(MONTH, @n_shelflife, getdate()), 112) + "'"
            END
            ELSE BEGIN
                SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(8),Lottable04, 112) >= N'" + convert(char(8), DateAdd(DAY, @n_shelflife, getdate()), 112) + "'"
            END
         END
         ELSE
			BEGIN
				-- if Shelf Life not provided, filter Lottable04 < Today date 
			   SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(8),Lottable04, 112) >= N'" + convert(char(8), getdate(), 112) + "'"
			END 
      END 

      IF @b_debug = 1
      BEGIN
        SELECT 'c_limitstring', @c_limitstring
      END

      SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)  
      SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)  		

		SELECT @c_sql = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +  
			" SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT," +  
			" QTYAVAILABLE = CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
			               " SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) < " + @c_UOMBase +
			         " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
			              " - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) " +
			         " WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +
			               " SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) % " + @c_UOMBase + " = 0 " +
			         " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +
			               " - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) " +
			         " ELSE " +
			         " ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) " +
			         " -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated,0))) % " + @c_UOMBase + " " + 
			         " END " +
			" FROM LOT (NOLOCK) " +  
			" INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT " + 
			" INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " + 
			" INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
			" LEFT OUTER JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID " +
			" LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +
			"				  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " + 
			"				  WHERE  p.Orderkey = ORDERS.Orderkey " +
			"				  GROUP BY p.Lot, ORDERS.Facility) As P ON LOTXLOCXID.Lot = P.Lot AND LOC.Facility = P.Facility " +
			" WHERE LOTXLOCXID.STORERKEY = N'" + @c_storerkey + "'" + " AND LOTXLOCXID.SKU = N'" + @c_sku + "' " +  
			" AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +  
			" AND LOC.FACILITY = N'" + @c_facility + "'"  + @c_LimitString + " " +   
			" GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " + 
			" HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(ISNULL(P.QtyPreAllocated, 0))) >= " + @c_UOMBase + " " +
			@c_SortOrder

      EXEC (@c_sql)   

		IF @b_debug = 1 SELECT @c_sql				
   END
END



GO