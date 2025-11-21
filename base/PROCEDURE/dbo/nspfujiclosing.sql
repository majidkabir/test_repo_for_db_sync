SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspFujiClosing                                     */
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

--drop proc nspFujiClosing
CREATE PROC [dbo].[nspFujiClosing]
as
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_loc NVARCHAR(10),
   @c_sku NVARCHAR(20),
   @n_qty int,
   @c_lot01 NVARCHAR(18),
   @c_lot04 NVARCHAR(20),
   @c_id NVARCHAR(18),
   @n_adjqty int,
   @c_adjsku NVARCHAR(20),
   @c_adjloc NVARCHAR(10),
   @c_adjlot01 NVARCHAR(18),
   @c_adjid NVARCHAR(18),
   @n_qtyadj int,
   @d_lot04 datetime
   select * into #result from tempFujiClose
   update #result
   set lot01=""
   where lot01 is null
   declare cur1 cursor FAST_FORWARD READ_ONLY
   for
   select sku, loc, lot01, sum(qty) from tempFujiClose(nolock)
   group by sku, loc, lot01
   open cur1
   fetch next from cur1 into @c_sku, @c_loc, @c_lot01, @n_qty
   while (@@fetch_status=0)
   begin
      select @n_adjqty = sum(a.qty) from adjustmentdetail a (NOLOCK), lotattribute b (NOLOCK)
      where a.sku = @c_sku
      and a.loc = @c_loc
      and a.lot = b.lot
      and convert(char(10),a.adddate,103)="12/02/2001"
      and b.lottable01 = isnull(@c_lot01,"")
      update #result
      set qty = @n_qty + isnull(@n_adjqty,0)
      where sku = @c_sku
      and loc = @c_loc
      and lot01 = isnull(@c_lot01,"")
      fetch next from cur1 into @c_sku,  @c_loc, @c_lot01, @n_qty
   end
   declare cur2 cursor FAST_FORWARD READ_ONLY
   for
   select a.sku, a.loc, b.lottable01, b.lottable04, a.id, a.qty from adjustmentdetail a (nolock), lotattribute b (nolock)
   where convert(char(10),a.adddate,103)="12/02/2001"
   and a.lot = b.lot
   and not exists (select * from #result where sku=a.sku and loc=a.loc)
   order by a.sku
   open cur2
   fetch next from cur2 into @c_adjsku, @c_adjloc, @c_adjlot01, @d_lot04, @c_adjid, @n_qtyadj
   while (@@fetch_status=0)
   begin
      insert into #result
      values(@c_adjloc, @c_adjsku, @n_qtyadj, @c_adjlot01, convert(char(10),@d_lot04,103), @c_adjid)
      set @c_adjloc = ""
      set @c_adjsku = ""
      set @n_qtyadj = 0
      set @c_adjlot01 = ""
      set @d_lot04 = ""
      set @c_adjid = ""
      fetch next from cur2 into @c_adjsku, @c_adjloc, @c_adjlot01, @d_lot04, @c_adjid, @n_qtyadj
   end
   close cur2
   deallocate cur2
   select a.sku, b.descr, a.loc, isnull(a.lot01,"") Batch, isnull(sum(a.qty),0) Qty
   into #result2
   from #result a (nolock), sku b (nolock)
   where a.sku = b.sku
   group by a.sku, b.descr, a.loc, a.lot01
   select sku, descr,loc,batch,sum(qty) from #result2
   group by sku, descr,loc,batch
   drop table #result2
   /*
   select a.sku, b.descr, a.loc, isnull(a.lot01,"") Batch, isnull(sum(a.qty),0) Qty
   from #result2 a (nolock), sku b (nolock)
   where a.sku = b.sku
   group by a.sku, b.descr, a.loc, a.lot01
   */
   /*
   select a.sku, a.loc, a.lot01, sum(a.qty) AdjQty,sum(b.qty) OrigQty from #result a, tempfujiclose b
   where a.sku=b.sku
   and a.loc=b.loc
   and a.lot01=b.lot01
   group by a.sku, a.loc, a.lot01
   having sum(a.qty)<>sum(b.qty)
   order by a.sku
   */
   drop table #result
   close cur1
   deallocate cur1
end


GO