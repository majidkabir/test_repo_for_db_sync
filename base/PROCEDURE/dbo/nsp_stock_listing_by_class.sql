SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_stock_listing_by_class                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCedure [dbo].[nsp_stock_listing_by_class](
@c_storerkey_start NVARCHAR(15),
@c_storerkey_end NVARCHAR(15),
@c_sku_start NVARCHAR(20),
@c_sku_end NVARCHAR(20),
@c_class_start NVARCHAR(10),
@c_class_end NVARCHAR(10)
)
as
begin -- start procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_sku NVARCHAR(20),
   @c_descr NVARCHAR(60),
   @c_class NVARCHAR(10),
   @c_uom NVARCHAR(10),
   @n_qty int,
   @n_commitedqty int,
   @c_storerkey NVARCHAR(15),
   @n_qtyallocated int,
   @n_qtypicked int

   create table #result (
   storerkey NVARCHAR(15),
   sku NVARCHAR(20),
   descr NVARCHAR(60),
   class NVARCHAR(10),
   uom NVARCHAR(10),
   qty int,
   commitedqty int
   )

   select @n_qty = 0,
   @n_qtyallocated = 0,
   @n_qtypicked = 0,
   @n_commitedqty = 0

   declare cur1 cursor FAST_FORWARD READ_ONLY
   for
   select  a.storerkey, a.sku, b.descr, b.skugroup, c.packuom3, sum(a.qty)
   from lotxlocxid a (nolock),
   sku b (nolock),
   pack c (nolock)
   where a.storerkey = b. storerkey
   and a.sku = b.sku
   and b.packkey = c.packkey
   and a.qty>0
   and a.storerkey between @c_storerkey_start and @c_storerkey_end
   and a.sku between @c_sku_start and @c_sku_end
   and b.class between @c_class_start and @c_class_end
   group by a.storerkey, a.sku, b.descr, b.skugroup, c.packuom3
   order by a.storerkey, a.sku

   open cur1

   fetch next from cur1 into @c_storerkey, @c_sku, @c_descr, @c_class, @c_uom, @n_qty

   while (@@fetch_status=0)
   begin

      select @n_qtyallocated=qtyallocated,
      @n_qtypicked=qtypicked
      from orderdetail (nolock)
      where storerkey = @c_storerkey
      and sku = @c_sku

      set @n_commitedqty = @n_qtyallocated + @n_qtypicked

      insert into #result
      values(@c_storerkey, @c_sku, @c_descr, @c_class, @c_uom, @n_qty,@n_commitedqty )

      select @n_qty = 0,
      @n_qtyallocated = 0,
      @n_qtypicked = 0,
      @n_commitedqty = 0

      fetch next from cur1 into @c_storerkey, @c_sku, @c_descr, @c_class, @c_uom, @n_qty
   end

   close cur1
   deallocate cur1

   select * from #result
   order by class

   drop table #result

end -- end of procedure

GO