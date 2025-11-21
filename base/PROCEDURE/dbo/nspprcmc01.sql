SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nspPRCMC01]
  	@c_storerkey NVARCHAR(15) ,
  	@c_sku NVARCHAR(20) ,
  	@c_lot NVARCHAR(10) ,
  	@c_lottable01 NVARCHAR(18) ,
  	@c_lottable02 NVARCHAR(18) ,
  	@c_lottable03 NVARCHAR(18) ,
  	@c_lottable04 datetime,
  	@c_lottable05 datetime,
  	@c_uom NVARCHAR(10) ,
	@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
  	@n_uombase int ,
  	@n_qtylefttofulfill int,
   @c_OtherParms NVARCHAR(200) = NULL 
  AS
  begin -- main
  
  	/* Get SKU Shelf Life */
  	DECLARE @n_acceptage int,
  			  @n_shelflife int
  	SELECT @n_acceptage = BUSR6,	
  			 @n_shelflife = ShelfLife
  	FROM  Sku (nolock)
  	WHERE Storerkey = @c_storerkey 
	AND   sku = @c_sku
  	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@n_acceptage)) IS NULL SELECT @n_acceptage = 0
  	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@n_shelflife)) IS NULL SELECT @n_shelflife = 0
  	
  	if dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) is not null
  	begin
  		declare preallocate_cursor_candidates CURSOR FAST_FORWARD READ_ONLY FOR
  			select lot.storerkey, lot.sku, lot.lot, 
  				qtyavailable = SUM(lotxlocxid.qty-lotxlocxid.qtyallocated-lotxlocxid.qtypicked) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
  			from lotxlocxid (nolock) 
			join lot (nolock) on lotxlocxid.lot = lot.lot
  			join lotattribute (nolock) on lotxlocxid.lot = lotattribute.lot
  			join loc (nolock) on lotxlocxid.loc = loc.loc
         LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) 
         					  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) 
         					  WHERE  p.Orderkey = ORDERS.Orderkey 
         					  AND    p.Storerkey = dbo.fnc_RTrim(@c_storerkey)
         					  AND    p.SKU = dbo.fnc_RTrim(@c_sku)
         					  AND    p.Qty > 0
         					  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility	
  			where lotxlocxid.lot = @c_lot
 				and lotxlocxid.qty > 0
  				and lot.status = 'OK' and loc.status = 'OK' AND loc.LocationFlag = 'NONE' 
				AND LOC.Facility = @c_facility  -- Added By Ricky for IDSV5
  				and loc.locationflag = 'NONE'
  				and (loc.locationtype = 'SELECTIVE' or loc.locationtype = 'DOUBLEDEEP')
  				-- and DATEDIFF(DAY, GETDATE(), (lottable04 - @n_shelflife)) <= @n_acceptage  				
  				-- and DATEDIFF(DAY, Lottable04 - @n_shelflife, GETDATE()) <= @n_acceptage  	
  				and DATEDIFF(DAY, GETDATE(), lottable04) >= @n_acceptage				
  			group by lot.storerkey, lot.sku, lot.lot, lottable04 
         having SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0
  			order by lottable04
  	end
  	else -- if dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) is not null
  	begin
  		declare preallocate_cursor_candidates CURSOR FAST_FORWARD READ_ONLY FOR 
  		select lot.storerkey, lot.sku, lot.lot, 
  				qtyavailable = SUM(lotxlocxid.qty-lotxlocxid.qtyallocated-lotxlocxid.qtypicked) - MIN(ISNULL(p.QTYPREALLOCATED, 0))
  			from lotxlocxid (nolock) 
			join lot (nolock) on lotxlocxid.lot = lot.lot
  			join lotattribute (nolock) on lotxlocxid.lot = lotattribute.lot
  			join loc (nolock) on lotxlocxid.loc = loc.loc
         LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) 
         					  FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) 
         					  WHERE  p.Orderkey = ORDERS.Orderkey 
         					  AND    p.Storerkey = dbo.fnc_RTrim(@c_storerkey)
         					  AND    p.SKU = dbo.fnc_RTrim(@c_sku)
         					  AND    p.Qty > 0
         					  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility	
  			where lotxlocxid.storerkey = @c_storerkey
  				and lotxlocxid.sku = @c_sku
 				and lotxlocxid.qty > 0
  				and lot.status = 'OK' and loc.status = 'OK' AND loc.LocationFlag = 'NONE' 
				and loc.Facility = @c_facility  -- Added By Ricky for IDSV5
  				and loc.locationflag = 'NONE'
  				and (loc.locationtype = 'SELECTIVE' or loc.locationtype = 'DOUBLEDEEP')
  				-- and DATEDIFF(DAY, GETDATE(), (lottable04 - @n_shelflife)) <= @n_acceptage
  				-- and DATEDIFF(DAY, Lottable04 - @n_shelflife, GETDATE()) <= @n_acceptage  	
  				and DATEDIFF(DAY, GETDATE(), lottable04) >= @n_acceptage
  			group by lot.storerkey, lot.sku, lot.lot, lottable04
         having SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0
  			order by lottable04
  	end
  end -- main

GO