SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_Incoming_Item_Receipt                          */
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

CREATE PROC [dbo].[nsp_Incoming_Item_Receipt](
@c_fr_storerkey NVARCHAR(15),
@c_to_storerkey NVARCHAR(15),
@c_fr_potype NVARCHAR(10),
@c_to_potype NVARCHAR(10),
@c_fr_skugroup NVARCHAR(10),
@c_to_skugroup NVARCHAR(10),
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
   @d_loadingdate datetime,
   @d_vesseldate datetime,
   @c_sku NVARCHAR(20),
   @c_skudescription NVARCHAR(60),
   @c_uom NVARCHAR(10),
   @n_qtyordered int,
   @n_qtyreceived int,
   @n_qtyos int,
   @n_agedtoday int,
   @n_aged7 int,
   @n_aged14 int,
   @c_todayload NVARCHAR(8),
   @c_7afterload NVARCHAR(8),
   @c_load NVARCHAR(8),
   @c_potype_descr NVARCHAR(250),
   @n_total_po int
   create table #temppo(
   storerkey NVARCHAR(15),
   potype NVARCHAR(250) null,
   skugroup NVARCHAR(10) null,
   pokey NVARCHAR(18)null,
   polinenumber NVARCHAR(18) null,
   podate datetime null,
   vesseldate datetime null,
   sku NVARCHAR(20) null,
   descr NVARCHAR(60) null,
   uom NVARCHAR(10) null,
   poqty int null,
   recqty int null,
   osqty int null,
   agedtoday int null,
   aged7 int null,
   aged14 int null
   )
   declare po_cur cursor FAST_FORWARD READ_ONLY
   for
   select a.storerkey, a.potype, c.skugroup, a.pokey, b.polinenumber, a.podate, a.loadingdate, a.vesseldate, b.sku, b.skudescription, b.uom, b.qtyordered, b.qtyreceived
   from po a(nolock), podetail b(nolock), sku c(nolock)
   where a.pokey = b.pokey
   and b.sku = c.sku
   and a.storerkey between @c_fr_storerkey and @c_to_storerkey
   and a.potype between @c_fr_potype and @c_to_potype
   and c.skugroup between @c_fr_sku and @c_to_sku
   and a.podate between @d_fr_podate and @d_to_podate
   and b.sku between @c_fr_sku and @c_to_sku
   open po_cur
   fetch next from po_cur into @c_storerkey, @c_potype, @c_skugroup, @c_pokey, @c_polinenumber, @d_podate, @d_loadingdate, @d_vesseldate, @c_sku, @c_skudescription, @c_uom, @n_qtyordered, @n_qtyreceived
   while (@@fetch_status=0)
   begin
      select @c_potype_descr=description from codelkup
      where listname="POTYPE"
      and code=@c_potype
      if (@n_qtyordered<>@n_qtyreceived)
      set @n_qtyos = @n_qtyordered - @n_qtyreceived
   else
      set @n_qtyos = 0
      set @c_todayload = convert(char(8),getdate(),103)      -- today's date
      set @c_7afterload = convert(char(8),(getdate()+7),103) -- date after the 7th day of loading date
      set @c_load = convert(char(8),@d_loadingdate,103)      -- loading date
      if @c_load = @c_todayload
      begin
         set @n_agedtoday = @n_qtyos
         set @n_aged7 = 0
         set @n_aged14 = 0
      end
   else if @c_load > @c_todayload and @c_load<=@c_7afterload
      begin
         set @n_agedtoday = 0
         set @n_aged7 = @n_qtyos
         set @n_aged14 = 0
      end
   else
      begin
         set @n_agedtoday = 0
         set @n_aged7 = 0
         set @n_aged14 = @n_qtyos
      end
      insert into #temppo
      values(@c_storerkey,@c_potype_descr,@c_skugroup,@c_pokey,@c_polinenumber,@d_podate,isnull(@d_vesseldate,""),@c_sku,@c_skudescription,@c_uom,@n_qtyordered,@n_qtyreceived,@n_qtyos,@n_agedtoday,@n_aged7,@n_aged14)
      set @n_agedtoday = 0
      set @n_aged7 = 0
      set @n_aged14 = 0
      set @c_potype_descr=""
      fetch next from po_cur into @c_storerkey, @c_potype, @c_skugroup, @c_pokey, @c_polinenumber, @d_podate, @d_loadingdate, @d_vesseldate, @c_sku, @c_skudescription, @c_uom, @n_qtyordered, @n_qtyreceived
   end
   select @n_total_po=count(distinct pokey) from #temppo
   where poqty<>recqty
   select *,@n_total_po from #temppo
   where osqty<>0
   drop table #temppo
   close po_cur
   deallocate po_cur
end

GO