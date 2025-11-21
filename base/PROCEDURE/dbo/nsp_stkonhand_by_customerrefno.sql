SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_stkonhand_by_customerrefno                     */
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

CREATE PROC [dbo].[nsp_stkonhand_by_customerrefno](
@c_storerkey_start NVARCHAR(15),
@c_storerkey_end NVARCHAR(15),
@c_sku_start NVARCHAR(20),
@c_sku_end NVARCHAR(20)
)
as begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   create table #result (
   storerkey NVARCHAR(15),
   sku NVARCHAR(20),
   descr NVARCHAR(60),
   lot01 NVARCHAR(18) null,
   qtyonhand int null,
   refno NVARCHAR(10) null
   )

   declare @c_cusrefno NVARCHAR(10),
   @c_storerkey NVARCHAR(15),
   @c_sku NVARCHAR(20),
   @c_lot01 NVARCHAR(18),
   @n_qtyonhand int,
   @c_descr NVARCHAR(60)


   declare cur1 cursor FAST_FORWARD READ_ONLY
   for
   select a.storerkey, a.sku, c.descr, b.lottable01, sum(a.qty)
   from
   lotxlocxid a (nolock),
   lotattribute b (nolock),
   sku c (nolock)
   where a.lot=b.lot
   and a.storerkey=b.storerkey
   and a.sku=b.sku
   and a.lot=b.lot
   and b.sku=c.sku
   and b.storerkey=c.storerkey
   and a.storerkey between @c_storerkey_start and @c_storerkey_end
   and a.sku between @c_sku_start and @c_sku_end
   group by a.storerkey, a.sku,c.descr, b.lottable01, c.descr
   having sum(a.qty)>0


   open cur1

   fetch next from cur1 into @c_storerkey, @c_sku, @c_descr,@c_lot01, @n_qtyonhand

   while (@@fetch_status=0)
   begin
      select @c_cusrefno=a.customerrefno
      from transfer a (nolock), transferdetail b (nolock)
      where a.transferkey = b.transferkey
      and b.lottable01 = @c_lot01

      insert into #result
      values(@c_storerkey, @c_sku, @c_descr, @c_lot01, @n_qtyonhand, @c_cusrefno)

      fetch next from cur1 into @c_storerkey, @c_sku, @c_descr,@c_lot01, @n_qtyonhand
   end

   close cur1
   deallocate cur1

   select * from #result

   drop table #result

end -- end of proc

GO