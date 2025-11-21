SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROCEDURE [dbo].[nspPRIDS25]  
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
BEGIN  
   
   DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int  
   DECLARE @c_LimitString NVARCHAR(255) -- To limit the where clause based on the user input  
	DECLARE @c_Limitstring1 NVARCHAR(255)  , @c_lottable04label NVARCHAR(20)
	DECLARE @c_UOMBase NVARCHAR(10)
	DECLARE @sql NVARCHAR(max)
	declare @n_shelflife int 
   declare @n_continue int

   SELECT @b_success= 0, @n_err= 0, @c_errmsg="",@b_debug= 0
	SELECT @c_UOMBase = @n_uombase
     
   If @d_lottable04 = '1900-01-01'
	Begin
		Select @d_lottable04 = null
	End
     
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL 
   BEGIN     
		/* Lot specific candidate set */  
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT,  
             QTYAVAILABLE =  SUM(LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))
      FROM  LOTXLOCXID (NOLOCK) 
      INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot 
      INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot 
      INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC 
		LEFT OUTER JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID 
      LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) 
      					  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) 
      					  WHERE  p.Orderkey = ORDERS.Orderkey 
      					  AND    p.Storerkey = @c_storerkey 
      					  AND    p.SKU = @c_sku 
							  AND    p.qty > 0 
							  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility	
      WHERE LOC.Facility = @c_facility
 		AND   LOT.LOT = @c_lot
		GROUP BY LOT.STORERKEY,LOT.SKU,LOT.LOT, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04
		ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02 
		
      IF @b_debug = 1
		BEGIN
			SELECT ' Lot not null'
		END
   END  
   ELSE  
   BEGIN            
	   /* Everything Else when no lottable supplied */  
		SELECT @n_shelflife = convert(int, SKU.SUSR2)
		FROM SKU (NOLOCK)
		WHERE SKU = @c_sku
		AND STORERKEY = @c_storerkey
      
      SELECT @c_lottable04label = SKU.Lottable04label
      FROM  SKU (NOLOCK)
      WHERE SKU = @c_sku
		AND STORERKEY = @c_storerkey
      
      SELECT @c_Limitstring1 = ''

      IF @c_lottable04label = 'EXP_DATE'
      BEGIN
			IF @n_shelflife > 0
			BEGIN
				SELECT @c_Limitstring1 = dbo.fnc_RTrim(@c_LimitString1) + " AND lottable04  > N'"  +  dbo.fnc_RTrim(convert(char(15), DateAdd(day, @n_shelflife, getdate()), 106)) + "'"
			END             
      END   

		SELECT @SQL = 'DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  ' + 
		   'SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT,   ' +  
		   'QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)))' +
		   'FROM LOTXLOCXID (NOLOCK) ' +
		   'INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot ' +
		   'INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot ' +
		   'INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
			'LEFT OUTER JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID ' + 			
		   'LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) ' +
		   '					  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) ' +
		   '					  WHERE  p.Orderkey = ORDERS.Orderkey ' +
		   '					  AND    p.Storerkey = N''' + @c_storerkey + '''' +
		   '					  AND    p.SKU = N''' + @c_sku + '''' +
			'					  AND    p.qty > 0 ' +
		   '					  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility	' +
		   ' WHERE LOTXLOCXID.STORERKEY = N''' + @c_storerkey + ''' ' +
		   ' AND LOTXLOCXID.SKU = N''' + @c_sku +  ''' '   +
		   ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" And LOC.LocationFlag = "NONE" ' +  
		   ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_LimitString1 + ' ' + 
			' GROUP BY LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02 ' +  
		   ' HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0) ' +
		   ' ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02 '			
      
		EXEC (@SQL)  
		
      IF @b_debug = 1
      BEGIN
			SELECT @SQL
			SELECT 'LIMITSTRING', @c_Limitstring1
      END
  	END  
END

GO