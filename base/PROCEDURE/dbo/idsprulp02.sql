SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: idsPRULP02                                         */  
/* Creation Date: 04-Jun-2002                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Pre Allocation Strategy                                     */  
/*                                                                      */  
/* Called By: Exceed Allocate Orders                                    */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 04-Jun-2002            1.0 Initial Version                           */
/* 31-Mar-2003  Ricky Yee 1.1 Latest Change from IDSPH_CDC              */
/************************************************************************/  
CREATE proc [dbo].[idsPRULP02]
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
  	@n_qtylefttofulfill int
  AS
  begin -- main
   SET NOCOUNT ON 
  	/* Get SKU Shelf Life */
  	DECLARE @n_shelflife int
  	SELECT @n_shelflife = Sku.Shelflife 
  	FROM  Sku (nolock)
  	WHERE SKU.sku = @c_sku
  	IF LTRIM(RTRIM(@n_shelflife)) IS NULL SELECT @n_shelflife = 0
  	
  	if ltrim(rtrim(@c_lot)) is not null
  	begin
  		declare preallocate_cursor_candidates scroll cursor
  		for
  			select lot.storerkey, lot.sku, lot.lot, 
  				qtyavailable = (lot.qty-lot.qtyallocated-lot.qtypicked) - (lot.qtypreallocated+lot.qtyonhold)
  			from lotxlocxid (nolock) join lot (nolock)
  				on lotxlocxid.lot = lot.lot
  			join lotattribute (nolock)
  				on lotxlocxid.lot = lotattribute.lot
  			join loc (nolock)
  				on lotxlocxid.loc = loc.loc
         join id(nolock)    -- SOS131215 Start ang01
            on lotxlocxid.id = id.id   --SOS131215 End ang01
  			where lotxlocxid.lot = @c_lot
 				and lotxlocxid.qty > 0
  				and lot.status = 'OK' 
            and Id.status = 'OK' -- SOS131215 Start ang01
            and Loc.status = 'OK' -- SOS131215 End  ang01
				AND LOC.Facility = @c_facility  -- Added By Ricky for IDSV5
  				and loc.locationflag = 'NONE'
  				and (loc.locationtype = 'CASE' or loc.locationtype = 'PICK')
  				and dateadd(day, @n_shelflife, lottable04) < getdate()
  			group by lot.storerkey, lot.sku, lot.lot, lottable04, lot.qty, lot.qtyallocated, lot.qtypicked,
 								lot.qtypreallocated, lot.qtyonhold
  			having (lot.qty-lot.qtyallocated-lot.qtypicked) - (lot.qtypreallocated+lot.qtyonhold) > 0
  			order by min(loc.hostwhcode), lottable04
  	end
  	else -- if ltrim(rtrim(@c_lot)) is not null
  	begin
  		declare preallocate_cursor_candidates scroll cursor
  		for
  		select lot.storerkey, lot.sku, lot.lot, 
  				qtyavailable = (lot.qty-lot.qtyallocated-lot.qtypicked) - (lot.qtypreallocated+lot.qtyonhold)
  			from lotxlocxid (nolock) join lot (nolock)
  				on lotxlocxid.lot = lot.lot
  			join lotattribute (nolock)
  				on lotxlocxid.lot = lotattribute.lot
  			join loc (nolock)
  				on lotxlocxid.loc = loc.loc
         join id(nolock)    -- SOS131215 Start ang01
            on lotxlocxid.id = id.id   --SOS131215 End ang01
  			where lotxlocxid.storerkey = @c_storerkey
  				and lotxlocxid.sku = @c_sku
 				and lotxlocxid.qty > 0
  				and lot.status = 'OK' 
            and Id.status = 'OK' -- SOS131215 Start ang01
            and Loc.status = 'OK' -- SOS131215 End  ang01
				AND LOC.Facility = @c_facility  -- Added By Ricky for IDSV5
  				and loc.locationflag = 'NONE'
  				and (loc.locationtype = 'CASE' or loc.locationtype = 'PICK')
  				and dateadd(day, @n_shelflife, lottable04) < getdate()
  			group by lot.storerkey, lot.sku, lot.lot, lottable04, lot.qty, lot.qtyallocated, lot.qtypicked,
 								lot.qtypreallocated, lot.qtyonhold
  			having (lot.qty-lot.qtyallocated-lot.qtypicked) - (lot.qtypreallocated+lot.qtyonhold) > 0
  			order by min(loc.hostwhcode), lottable04
  	end
  end -- main


GO