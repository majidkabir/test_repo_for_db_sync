SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspinvreport2] (
 @c_storer  NVARCHAR(20), -- SOS10835
 @c_principal NVARCHAR(18), -- SOS10835
 @c_sku_start NVARCHAR(18),
 @c_sku_end NVARCHAR(18),
-- @c_whse NVARCHAR(10)
 @c_facility NVARCHAR(5) -- SOS13230
 ) as
 begin
	-- sos 8627
	-- wally 22.nov.2002
	-- add back lottable03 (logical whse) as parameter and include ID in the result set
	-- deduct qtypicked as well just like the original design of this report from v3
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
 select  a.storerkey, 
 	c.company, 
 	a.sku, 
	Principal=d.susr3, -- SOS10835
	PrinDesc=e.Description, -- SOS10835
 	d.descr, 
 	b.lottable03,
 	b.lottable02, 
 	b.lottable04,
 	a.loc, 
 	sum(a.qty-a.qtyallocated-a.qtypicked),
	a.id,
	facility.facility -- SOS13230
 from lotxlocxid a inner join lotattribute b
 on a.lot = b.lot
 inner join storer c on a.storerkey = c.storerkey
 inner join sku d on a.sku = d.sku 
						and a.storerkey = d.storerkey
 left outer join codelkup e on e.code = d.susr3 and e.Listname = 'Principal' -- SOS10835
 inner join loc on a.loc = loc.loc -- SOS13230
 inner join facility on facility.facility = loc.facility -- SOS13230
 where a.sku between @c_sku_start and @c_sku_end
 and a.storerkey = @c_storer -- SOS10835
 and d.susr3 = @c_principal -- SOS10835
-- and b.lottable03 = @c_whse
 and facility.facility = @c_facility -- SOS13230
 group by  a.storerkey, c.company, a.sku, d.descr, b.lottable03,b.lottable02, lottable04, a.loc, a.id
			  ,d.susr3, e.Description
			  ,facility.facility -- SOS13230
 having sum(a.qty-a.qtyallocated) <> 0
 order by a.loc
 end


GO