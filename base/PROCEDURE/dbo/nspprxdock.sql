SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspPRxdock]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@c_lottable04 datetime ,
@c_lottable05 datetime ,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(10),  -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN -- main
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int
   DECLARE @c_manual NVARCHAR(1) 
   DECLARE @c_LimitString NVARCHAR(255) -- To limit the where clause based on the user input
   
   SELECT @b_success=0, @n_err=0, @c_errmsg="",@b_debug=0
   SELECT @c_manual = 'N'
   
   SELECT @b_debug = 0
   
   IF @b_debug = 1
   BEGIN
      SELECT "nspPR_Lot : Before Lot Lookup ....."
      SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03    
   END
   
   -- when any of the lottables is supplied, get the specific lot
   IF (@c_lottable01<>'' OR @c_lottable02<>'' OR @c_lottable03<>'' OR 
   @c_lottable04 IS NOT NULL OR @c_lottable05 IS NOT NULL)
   BEGIN
      SELECT @c_manual = 'Y'
   END
   
   IF @b_debug = 1
   BEGIN
      SELECT "nspPR_Lot : After Lot Lookup ....."
      SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03
   END
   
   DECLARE @c_UOMBase NVARCHAR(10)
   IF @n_uombase <= 0 SELECT @n_uombase = 1
   SELECT @c_UOMBase = @n_uombase
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN     
      /* Lot specific candidate set */
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,
        QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < @c_UOMBase
      							 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) 
      							 WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % @c_UOMBase = 0
      							 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) 
      							 ELSE 
      									SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))  
      								 - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % @c_UOMBase)  
      							 END 
      FROM LOT (nolock)
      INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT
      INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
      LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) 
      				  FROM   PreallocatePickDetail p (NOLOCK), ORDERS (NOLOCK)
      				  WHERE  p.Orderkey = ORDERS.Orderkey
      				  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility
      WHERE LOC.Facility = @c_facility
         AND LOT.LOT = @c_lot
         AND LOC.Locationtype = 'XDOCK'
      GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT 
      ORDER BY LOT.LOT     
   END
   ELSE
   BEGIN          
      /* Everything Else when no lottable supplied */
      IF @c_manual = 'N' 
      BEGIN
         DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,
            QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < @c_UOMBase
   								 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) 
   								 WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) % @c_UOMBase = 0
   								 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) 
   								 ELSE 
   										SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))  
   										- ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % @c_UOMBase) 
   								 END 
         FROM LOT (nolock)
         INNER JOIN LOTXLOCXID (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT
         INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
         LEFT OUTER JOIN (SELECT p.lot, ORDERS.facility, QtyPreallocated = SUM(p.Qty) 
   					        FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)
   					        WHERE p.Orderkey = ORDERS.Orderkey
   					        GROUP BY p.Lot, ORDERS.Facility) p ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility
         WHERE LOT.STORERKEY = @c_storerkey 
            AND LOT.SKU = @c_sku
            AND LOT.STATUS = "OK" 
            AND LOC.Facility = @c_facility
            AND LOC.Locationtype = 'XDOCK'
         GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT
         HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(LOT.QTYPREALLOCATED, 0)) >= @c_UOMBase
         ORDER BY LOT.LOT 
      END
      ELSE
      BEGIN
         SELECT @c_LimitString = ''
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)) <> ' '
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)) + "'"
   
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable02)) <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable02= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable02)) + "'"
   
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)) <> ' '
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)) + "'"
   
         IF @c_lottable04 <> ( select convert(datetime,'01/01/1900' ))
            SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable04= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @c_lottable04))) + "'"
   
         IF @c_lottable05 <> ( select convert(datetime,'01/01/1900' ))
   	      SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable05= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @c_lottable05))) + "'"			
   
         SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)
         SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)
         
   	   EXEC ("DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
            	"SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " + 
            	"QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < " + @c_UOMBase + 
            	"					 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " + 
            	"					 WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " + 
            	"					 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " + 
            	"					 ELSE   " +
            	"							 SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " + 
            	"							 - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +   
            	"					 END " +
            	"FROM LOTXLOCXID (NOLOCK) " + 
            	"INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot " + 
            	"INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +
            	"INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " + 
            	"LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) " +
            	"					  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
            	"					  WHERE  p.Orderkey = ORDERS.Orderkey " + 
            	"					  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility	" + 
            	"WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " + 
            	"AND LOT.SKU = N'" + @c_sku + "' " +
            	"AND LOT.STATUS = 'OK' " +
            	"AND LOC.Facility = N'" + @c_facility + "'" + @c_LimitString + " " +
               "AND LOC.Locationtype = 'XDOCK' " +
            	"GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT  " + 
            	"HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= " + @c_UOMBase + " " +
            	"ORDER BY lot.LOT ")
   
         IF @b_debug = 1
   	   BEGIN
      		select 'linit' = @c_limitstring    
      		declare @sql NVARCHAR(max)
      		select @sql = "SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " + 
               				"QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) <  " + @c_UOMBase + 
               				"					 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " + 
               				"					 WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " + 
               				"					 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " + 
               				"					 ELSE   " +
               				"							 SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " + 
               				"							 - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +   
               				"					 END " +
               				"FROM LOTXLOCXID (NOLOCK) " + 
               				"INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot " + 
               				"INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +
               				"INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " + 
               				"LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) " +
               				"					  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
               				"					  WHERE  p.Orderkey = ORDERS.Orderkey " + 
               				"					  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility	" + 
               				"WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " + 
               				"AND LOT.SKU = N'" + @c_sku + "' " +
               				"AND LOT.STATUS = 'OK' " +
               				"AND LOC.Facility = N'" + @c_facility + "'" + @c_LimitString + " " + 
                           "AND LOC.Locationtype = 'XDOCK' " +
               				"GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT  " + 
               				"HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) >= " + @c_UOMBase + " " +
               				"ORDER BY lot.LOT "
   		   select @sql
   	   END						
      END
   END
END -- main

GO