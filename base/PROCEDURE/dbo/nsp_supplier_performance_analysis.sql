SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_Supplier_Performance_Analysis                  */
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

CREATE PROC [dbo].[nsp_Supplier_Performance_Analysis](
@c_fr_storerkey NVARCHAR(15),
@c_to_storerkey NVARCHAR(15),
@c_fr_potype NVARCHAR(10),
@c_to_potype NVARCHAR(10),
@d_fr_podate datetime,
@d_to_podate datetime,
@c_fr_sku NVARCHAR(20),
@c_to_sku NVARCHAR(20)
)
as
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_storerkey NVARCHAR(15),
   @c_potype NVARCHAR(10),
   @c_skugroup NVARCHAR(10),
   @c_pokey NVARCHAR(18),
   @c_polinenumber NVARCHAR(18),
   @d_podate datetime,
   @d_vesseldate datetime,
   @d_receiveddate datetime,
   @c_sku NVARCHAR(20),
   @c_skudescription NVARCHAR(60),
   @c_uom NVARCHAR(10),
   @n_qtyordered int,
   @n_qtyreceived int,
   @c_potype_descr NVARCHAR(250),
   @n_beforedv int,
   @n_afterdv int,
   @n_beforedp float(8),
   @n_afterdp float(8),
   @n_ontimedp float(8),
   @n_total_po_var int,
   @n_total_po int
   create table #temppo(
   storerkey NVARCHAR(15),
   potype NVARCHAR(250)null,
   skugroup NVARCHAR(10) null,
   pokey NVARCHAR(18) null,
   polinenumber NVARCHAR(18) null,
   podate datetime null,
   vesseldate datetime null,
   receiveddate datetime null,
   sku NVARCHAR(20) null,
   descr NVARCHAR(60) null,
   uom NVARCHAR(10) null,
   poqty int null,
   recqty int null,
   beforedv int null,
   afterdv int null,
   beforedp int null,
   afterdp int null,
   ontimedp int null
   )
   set @c_storerkey = ""
   set @c_potype_descr = ""
   set @c_skugroup = ""
   set @c_pokey = ""
   set @c_polinenumber = ""
   set @d_podate = ""
   set @d_vesseldate = ""
   set @d_receiveddate = ""
   set @c_sku = ""
   set @c_skudescription = ""
   set @c_uom = ""
   set @n_qtyordered = 0
   set @n_qtyreceived  = 0
   set @n_beforedv = 0
   set @n_afterdv = 0
   set @n_beforedp = 0
   set @n_afterdp = 0
   set @n_ontimedp = 0
   declare po_cur cursor FAST_FORWARD READ_ONLY
   for
   select a.storerkey, a.potype, c.skugroup, a.externpokey, b.polinenumber, a.podate, a.vesseldate, b.sku, b.skudescription, b.uom, b.qtyordered, b.qtyreceived from po a(nolock), podetail b(nolock), sku c(nolock)
   where a.pokey = b.pokey
   and b.sku = c.sku
   and a.storerkey between @c_fr_storerkey and @c_to_storerkey
   and a.potype between @c_fr_potype and @c_to_potype
   and a.podate between @d_fr_podate and @d_to_podate
   and b.sku between @c_fr_sku and @c_to_sku
   open po_cur
   fetch next from po_cur into @c_storerkey, @c_potype, @c_skugroup, @c_pokey, @c_polinenumber, @d_podate, @d_vesseldate, @c_sku, @c_skudescription, @c_uom, @n_qtyordered, @n_qtyreceived
   while (@@fetch_status=0)
   begin
      select @d_receiveddate=receiptdate from receipt (NOLOCK)
      where pokey = @c_pokey
      if @d_vesseldate<>@d_receiveddate
      begin
         if (@d_vesseldate > @d_receiveddate) -- if received earlier than promised date
         begin
            set @n_beforedv = abs(datediff(day,@d_vesseldate,@d_receiveddate))
            set @n_afterdv = 0
         end
      else if (@d_vesseldate < @d_receiveddate) -- if received later than promised date
         begin
            set @n_beforedv = 0
            set @n_afterdv = abs(datediff(day,@d_vesseldate,@d_receiveddate))
         end
      else -- if received same as the promised date
         begin
            set @n_beforedv = 0
            set @n_afterdv = 0
         end
      end
      select @c_potype_descr=description from codelkup (NOLOCK)
      where listname="POTYPE"
      and code=@c_potype
      insert into #temppo
      values(@c_storerkey,@c_potype_descr,@c_skugroup,@c_pokey,@c_polinenumber,@d_podate,@d_vesseldate,@d_receiveddate,@c_sku,@c_skudescription,@c_uom,@n_qtyordered,@n_qtyreceived,@n_beforedv,@n_afterdv,null,null,null)
      set @c_storerkey = ""
      set @c_potype_descr = ""
      set @c_skugroup = ""
      set @c_pokey = ""
      set @c_polinenumber = ""
      set @d_podate = ""
      set @d_vesseldate = ""
      set @d_receiveddate = ""
      set @c_sku = ""
      set @c_skudescription = ""
      set @c_uom = ""
      set @n_qtyordered = 0
      set @n_qtyreceived  = 0
      set @n_beforedv = 0
      set @n_afterdv = 0
      set @n_beforedp = 0
      set @n_afterdp = 0
      set @n_ontimedp = 0
      fetch next from po_cur into @c_storerkey, @c_potype, @c_skugroup, @c_pokey, @c_polinenumber, @d_podate, @d_vesseldate, @c_sku, @c_skudescription, @c_uom, @n_qtyordered, @n_qtyreceived
   end
   select @n_total_po_var=count(distinct pokey) from #temppo -- to get total number of PO variance
   where poqty<>recqty
   select @n_total_po=count(distinct pokey) from #temppo -- to get total number of POs
   update #temppo
   set beforedp=(beforedv/@n_total_po)*100
   where beforedv<>0
   update #temppo
   set afterdp=(afterdv/@n_total_po)*100
   where afterdv<>0
   select *,@n_total_po_var from #temppo
   drop table #temppo
   close po_cur
   deallocate po_cur
end

GO