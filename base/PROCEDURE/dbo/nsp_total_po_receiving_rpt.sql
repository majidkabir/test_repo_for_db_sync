SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_Total_PO_Receiving_Rpt                         */
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

CREATE PROC [dbo].[nsp_Total_PO_Receiving_Rpt](
@c_from_storerkey NVARCHAR(15),
@c_to_storerkey NVARCHAR(15),
@datefrom datetime,
@dateto datetime
)
as
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_acdate NVARCHAR(10),
   @d_fr_acdate datetime,
   @d_to_acdate datetime,
   @c_storerkey NVARCHAR(15),
   @n_po_created int,
   @n_po_receipt int,
   @n_poline_receipt int,
   @n_storer_receipt int,
   @n_sku_receipt int,
   @n_qty_receipt int,
   @f_case_receipt float(8),
   @f_pallet_receipt float(8),
   @f_weight_receipt float(8),
   @f_cube_receipt float(8),
   @n_qty_received int,
   @c_packkey NVARCHAR(10),
   @f_weight float(8),
   @f_cube float(8),
   @f_casecnt float(8),
   @f_pallet float(8),
   @c_so_act_type NVARCHAR(20)




   create table #report1(
   acdate NVARCHAR(10),
   storerkey NVARCHAR(15),
   po_created int null,
   po_receipt int null,
   poline_receipt int null,
   sup_receipt int null,
   sku_receipt int null,
   qty_receipt int null,
   case_receipt float(8) null,
   pallet_receipt float(8) null,
   weight_receipt float(8) null,
   cube_receipt float(8) null,
   so_act_type NVARCHAR(20)
   )

   declare cur1 cursor FAST_FORWARD READ_ONLY
   for
   select distinct convert(char(10),adddate,103), storerkey
   from po
   where adddate >= (select Convert( datetime, @datefrom ))
   and adddate < (select DateAdd( day, 1, Convert( datetime,@dateto ) ) )
   and storerkey >= @c_from_storerkey
   and storerkey <= @c_to_storerkey


   open cur1

   fetch next from cur1 into @c_acdate, @c_storerkey

   while (@@fetch_status=0)
   begin
      insert into #report1(acdate, storerkey,so_act_type)
      values(@c_acdate, @c_storerkey,"Add")

      fetch next from cur1 into @c_acdate, @c_storerkey
   end


   close cur1
   deallocate cur1



   declare cur_1 cursor FAST_FORWARD READ_ONLY
   for
   select distinct convert(char(10),a.receiptdate,103), a.storerkey
   from receipt a (nolock), receiptdetail b (nolock)
   where a.receiptdate >= (select Convert( datetime, @datefrom ))
   and a.receiptdate < (select DateAdd( day, 1, Convert( datetime,@dateto ) ) )
   and a.storerkey = @c_storerkey
   and a.receiptkey = b.receiptkey
   and b.qtyexpected = b.qtyreceived


   open cur_1

   fetch next from cur_1 into @c_acdate, @c_storerkey

   while (@@fetch_status=0)
   begin
      insert into #report1(acdate, storerkey,so_act_type)
      values(@c_acdate, @c_storerkey,"Received")

      fetch next from cur_1 into @c_acdate, @c_storerkey
   end


   close cur_1
   deallocate cur_1





   declare cur2 cursor FAST_FORWARD READ_ONLY
   for
   select acdate, storerkey from #report1

   open cur2


   fetch next from cur2 into @c_acdate, @c_storerkey

   while (@@fetch_status=0)
   begin

      -- get number of PO created
      select @n_po_created=count(pokey)
      from po (nolock)
      where convert(char(10),adddate,103) = @c_acdate
      and storerkey = @c_storerkey

      update #report1
      set po_created = @n_po_created
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Add"

      -- get number of PO received
      select @n_po_receipt=count(distinct a.pokey)
      from receipt a (nolock), receiptdetail b (nolock)
      where convert(char(10),a.receiptdate,103) = @c_acdate
      and a.storerkey = @c_storerkey
      and a.receiptkey = b.receiptkey
      and b.qtyexpected = b.qtyreceived

      update #report1
      set po_receipt = @n_po_receipt
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Received"

      -- get number of PO line received
      select @n_poline_receipt=count(a.polinenumber)
      from podetail a (nolock), receipt b (nolock), receiptdetail c (nolock)
      where a.pokey = b.pokey
      and convert(char(10),b.receiptdate,103) = @c_acdate
      and b.storerkey = @c_storerkey
      and b.receiptkey = c.receiptkey
      and c.qtyexpected = c.qtyreceived

      update #report1
      set poline_receipt = @n_poline_receipt
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Received"

      -- get number of storers in receipt
      select @n_storer_receipt=count(distinct a.storerkey)
      from receipt a (nolock), receiptdetail b (nolock)
      where convert(char(10),a.receiptdate,103) = @c_acdate
      and a.storerkey = @c_storerkey
      and a.receiptkey = b.receiptkey
      and b.qtyexpected = b.qtyreceived

      update #report1
      set sup_receipt = @n_storer_receipt
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Received"

      -- get number of SKUs received
      select @n_sku_receipt=count(distinct b.sku)
      from receipt a (nolock), receiptdetail b (nolock)
      where convert(char(10),a.receiptdate,103) = @c_acdate
      and a.storerkey = @c_storerkey
      and a.receiptkey = b.receiptkey
      and b.qtyexpected = b.qtyreceived

      update #report1
      set sku_receipt = @n_sku_receipt
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Received"

      -- get qty received
      select @n_qty_receipt=sum(b.qtyreceived)
      from receipt a (nolock), receiptdetail b (nolock)
      where convert(char(10),a.receiptdate,103) = @c_acdate
      and a.storerkey = @c_storerkey
      and a.receiptkey = b.receiptkey
      and b.qtyexpected = b.qtyreceived

      update #report1
      set qty_receipt = isnull(@n_qty_receipt,0)
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Received"

      set @f_casecnt = 0
      set @f_pallet = 0
      set @f_weight_receipt = 0
      set @f_cube_receipt = 0
      set @f_case_receipt = 0
      set @f_pallet_receipt = 0

      declare cur3 cursor FAST_FORWARD READ_ONLY
      for
      select b.qtyreceived, c.packkey, b.qtyreceived*c.stdnetwgt, b.qtyreceived*c.stdcube
      from receipt a (nolock), receiptdetail b (nolock), sku c (nolock), pack d (nolock)
      where a.receiptkey = b.receiptkey
      and b.sku = c.sku
      and c.packkey = d.packkey
      and convert(char(10),a.receiptdate,103) = @c_acdate
      and a.storerkey = @c_storerkey

      open cur3

      fetch next from cur3 into @n_qty_received, @c_packkey, @f_weight, @f_cube

      while (@@fetch_status=0)
      begin

         select @f_casecnt = casecnt, @f_pallet = pallet
         from pack
         where packkey = @c_packkey

         if @f_casecnt = 0
         set @f_casecnt = 1

         if @f_pallet = 0
         set @f_pallet = 1

         -- get case receipt
         set @f_case_receipt = @f_case_receipt + (isnull(@n_qty_received,0)/isnull(@f_casecnt,1))

         -- get pallet receipt
         set @f_pallet_receipt = @f_pallet_receipt + (isnull(@n_qty_received,0)/isnull(@f_pallet,1))

         -- get weight receipt
         set @f_weight_receipt = @f_weight_receipt + @f_weight

         -- get cube receipt
         set @f_cube_receipt = @f_cube_receipt + @f_cube

         fetch next from cur3 into @n_qty_received, @c_packkey, @f_weight, @f_cube
      end

      update #report1
      set case_receipt = @f_case_receipt,
      pallet_receipt = @f_pallet_receipt,
      weight_receipt = @f_weight_receipt,
      cube_receipt = @f_cube_receipt
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Received"

      close cur3
      deallocate cur3



      fetch next from cur2 into @c_acdate, @c_storerkey
   end

   close cur2
   deallocate cur2

   select acdate,
   storerkey,
   isnull(sum(po_created),0),
   isnull(sum(po_receipt),0),
   isnull(sum(poline_receipt),0),
   isnull(sum(sup_receipt),0),
   isnull(sum(sku_receipt),0),
   isnull(sum(qty_receipt),0),
   isnull(sum(cast(round(case_receipt,0) as int)),0),
   isnull(sum(cast(round(pallet_receipt,0) as int)),0),
   isnull(sum(cast(round(weight_receipt,0)as int)),0),
   isnull(sum(cast(round(cube_receipt,0) as int )),0)
   from #report1
   group by acdate, storerkey
   order by acdate, storerkey

   drop table #report1

end -- end of stored procedure

GO