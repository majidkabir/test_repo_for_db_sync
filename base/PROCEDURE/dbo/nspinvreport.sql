SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nspinvreport] (
 @c_storer_start  NVARCHAR(20),
 @c_storer_end NVARCHAR(20),
 @c_sku_start NVARCHAR(18),
 @c_sku_end NVARCHAR(18),
 @c_whse NVARCHAR(10)
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
 	d.descr, 
 	b.lottable03,
 	b.lottable02, 
 	b.lottable04,
 	a.loc, 
 	sum(a.qty-a.qtyallocated-a.qtypicked),
	a.id
 from lotxlocxid a inner join lotattribute b
 on a.lot = b.lot
 inner join storer c
 on a.storerkey = c.storerkey
 inner join sku d
 on a.sku = d.sku
 where a.sku between @c_sku_start and @c_sku_end
 and a.storerkey between @c_storer_start and @c_storer_end
 and (b.lottable03 = @c_whse or b.lottable03 = '' )
 group by  a.storerkey, c.company, a.sku, d.descr, b.lottable03,b.lottable02, lottable04, a.loc, a.id
 having sum(a.qty-a.qtyallocated) <> 0
 order by a.loc
 end

GO