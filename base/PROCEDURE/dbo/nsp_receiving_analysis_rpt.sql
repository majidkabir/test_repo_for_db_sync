SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_Receiving_Analysis_Rpt                         */
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

CREATE PROCedure [dbo].[nsp_Receiving_Analysis_Rpt](
@c_fr_storerkey NVARCHAR(15),
@c_to_storerkey NVARCHAR(15),
@d_fr_receiptdate datetime,
@d_to_receiptdate datetime,
@c_fr_skugroup NVARCHAR(15),
@c_to_skugroup NVARCHAR(15),
@c_show_cube NVARCHAR(1),
@c_show_case NVARCHAR(1),
@c_show_pallet NVARCHAR(1),
@c_show_weight NVARCHAR(1),
@c_show_inv NVARCHAR(1),
@c_show_sku NVARCHAR(1)
)
as
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   set @c_show_cube = upper(@c_show_cube)
   set @c_show_case = upper(@c_show_case)
   set @c_show_pallet = upper(@c_show_pallet)
   set @c_show_weight = upper(@c_show_weight)
   set @c_show_inv = upper(@c_show_inv)
   set @c_show_sku = upper(@c_show_sku)
   set nocount on
   declare @n_pd1 int,
   @n_pd2 int,
   @n_pd3 int,
   @n_pd4 int,
   @n_pd5 int,
   @n_pd6 int,
   @n_pd7 int,
   @n_pd8 int,
   @n_pd9 int,
   @n_pd10 int,
   @n_pd11 int,
   @n_pd12 int,
   @n_wk1 int,
   @n_wk2 int,
   @n_wk3 int,
   @n_wk4 int,
   @n_wk5 int,
   @f_cubepd1 float(8),
   @f_cubepd2 float(8),
   @f_cubepd3 float(8),
   @f_cubepd4 float(8),
   @f_cubepd5 float(8),
   @f_cubepd6 float(8),
   @f_cubepd7 float(8),
   @f_cubepd8 float(8),
   @f_cubepd9 float(8),
   @f_cubepd10 float(8),
   @f_cubepd11 float(8),
   @f_cubepd12 float(8),
   @f_casepd1 float(8),
   @f_casepd2 float(8),
   @f_casepd3 float(8),
   @f_casepd4 float(8),
   @f_casepd5 float(8),
   @f_casepd6 float(8),
   @f_casepd7 float(8),
   @f_casepd8 float(8),
   @f_casepd9 float(8),
   @f_casepd10 float(8),
   @f_casepd11 float(8),
   @f_casepd12 float(8),
   @f_palletpd1 float(8),
   @f_palletpd2 float(8),
   @f_palletpd3 float(8),
   @f_palletpd4 float(8),
   @f_palletpd5 float(8),
   @f_palletpd6 float(8),
   @f_palletpd7 float(8),
   @f_palletpd8 float(8),
   @f_palletpd9 float(8),
   @f_palletpd10 float(8),
   @f_palletpd11 float(8),
   @f_palletpd12 float(8),
   @f_weightpd1 float(8),
   @f_weightpd2 float(8),
   @f_weightpd3 float(8),
   @f_weightpd4 float(8),
   @f_weightpd5 float(8),
   @f_weightpd6 float(8),
   @f_weightpd7 float(8),
   @f_weightpd8 float(8),
   @f_weightpd9 float(8),
   @f_weightpd10 float(8),
   @f_weightpd11 float(8),
   @f_weightpd12 float(8),
   @f_skupd1 float(8),
   @f_skupd2 float(8),
   @f_skupd3 float(8),
   @f_skupd4 float(8),
   @f_skupd5 float(8),
   @f_skupd6 float(8),
   @f_skupd7 float(8),
   @f_skupd8 float(8),
   @f_skupd9 float(8),
   @f_skupd10 float(8),
   @f_skupd11 float(8),
   @f_skupd12 float(8),
   @f_invpd1 float(8),
   @f_invpd2 float(8),
   @f_invpd3 float(8),
   @f_invpd4 float(8),
   @f_invpd5 float(8),
   @f_invpd6 float(8),
   @f_invpd7 float(8),
   @f_invpd8 float(8),
   @f_invpd9 float(8),
   @f_invpd10 float(8),
   @f_invpd11 float(8),
   @f_invpd12 float(8),
   @f_cubewk1 float(8),
   @f_cubewk2 float(8),
   @f_cubewk3 float(8),
   @f_cubewk4 float(8),
   @f_cubewk5 float(8),
   @f_casewk1 float(8),
   @f_casewk2 float(8),
   @f_casewk3 float(8),
   @f_casewk4 float(8),
   @f_casewk5 float(8),
   @f_palletwk1 float(8),
   @f_palletwk2 float(8),
   @f_palletwk3 float(8),
   @f_palletwk4 float(8),
   @f_palletwk5 float(8),
   @f_weightwk1 float(8),
   @f_weightwk2 float(8),
   @f_weightwk3 float(8),
   @f_weightwk4 float(8),
   @f_weightwk5 float(8),
   @f_skuwk1 float(8),
   @f_skuwk2 float(8),
   @f_skuwk3 float(8),
   @f_skuwk4 float(8),
   @f_skuwk5 float(8),
   @f_invwk1 float(8),
   @f_invwk2 float(8),
   @f_invwk3 float(8),
   @f_invwk4 float(8),
   @f_invwk5 float(8),
   @n_month int,
   @d_receiptdate datetime,
   @c_storerkey NVARCHAR(15),
   @c_skugroup NVARCHAR(15),
   @n_qtyreceived int,
   @n_year int,
   @f_total_cube float(8),
   @f_total_case float(8),
   @f_total_pallet float(8),
   @f_total_weight float(8),
   @f_total_sku float(8),
   @f_total_inv float(8),
   @c_cube NVARCHAR(1),
   @c_case NVARCHAR(1),
   @c_pallet NVARCHAR(1),
   @c_weight NVARCHAR(1),
   @c_nosku NVARCHAR(1),
   @c_noinv NVARCHAR(1),
   @f_cube float(8),
   @n_current_month int,
   @f_ytd_cube float(8),
   @f_ytd_case float(8),
   @f_ytd_pallet float(8),
   @f_ytd_weight float(8),
   @f_ytd_sku float(8),
   @f_ytd_inv float(8),
   @f_mtd_cube float(8),
   @f_mtd_case float(8),
   @f_mtd_pallet float(8),
   @f_mtd_weight float(8),
   @f_mtd_sku float(8),
   @f_mtd_inv float(8),
   @c_pre_storerkey NVARCHAR(15), -- used for storerkey group break
   @c_cur_storerkey NVARCHAR(15), -- same as above
   @c_pre_skugroup NVARCHAR(15), -- used for sku group break
   @c_cur_skugroup NVARCHAR(15),   -- same as above
   @f_casecnt float(8),
   @f_pallet float(8),
   @f_weight float(8),
   @f_nosku float(8),
   @f_noinv float(8),
   @n_month_cnt int, -- used for looping
   @n_week_cnt int   -- used for looping
   /*****************
   Initialization
   ******************/
   set @n_month_cnt = 1
   set @n_week_cnt = 1
   set @f_cubepd1 = 0
   set @f_cubepd2 = 0
   set @f_cubepd3 = 0
   set @f_cubepd4 = 0
   set @f_cubepd5 = 0
   set @f_cubepd6 = 0
   set @f_cubepd7 = 0
   set @f_cubepd8 = 0
   set @f_cubepd9 = 0
   set @f_cubepd10 = 0
   set @f_cubepd11 = 0
   set @f_cubepd12 = 0
   set @f_cubewk1 = 0
   set @f_cubewk2 = 0
   set @f_cubewk3 = 0
   set @f_cubewk4 = 0
   set @f_cubewk5 = 0
   set @f_casepd1 = 0
   set @f_casepd2 = 0
   set @f_casepd3 = 0
   set @f_casepd4 = 0
   set @f_casepd5 = 0
   set @f_casepd6 = 0
   set @f_casepd7 = 0
   set @f_casepd8 = 0
   set @f_casepd9 = 0
   set @f_casepd10 = 0
   set @f_casepd11 = 0
   set @f_casepd12 = 0
   set @f_casewk1 = 0
   set @f_casewk2 = 0
   set @f_casewk3 = 0
   set @f_casewk4 = 0
   set @f_casewk5 = 0
   set @f_palletpd1 = 0
   set @f_palletpd2 = 0
   set @f_palletpd3 = 0
   set @f_palletpd4 = 0
   set @f_palletpd5 = 0
   set @f_palletpd6 = 0
   set @f_palletpd7 = 0
   set @f_palletpd8 = 0
   set @f_palletpd9 = 0
   set @f_palletpd10 = 0
   set @f_palletpd11 = 0
   set @f_palletpd12 = 0
   set @f_palletwk1 = 0
   set @f_palletwk2 = 0
   set @f_palletwk3 = 0
   set @f_palletwk4 = 0
   set @f_palletwk5 = 0
   set @f_weightpd1 = 0
   set @f_weightpd2 = 0
   set @f_weightpd3 = 0
   set @f_weightpd4 = 0
   set @f_weightpd5 = 0
   set @f_weightpd6 = 0
   set @f_weightpd7 = 0
   set @f_weightpd8 = 0
   set @f_weightpd9 = 0
   set @f_weightpd10 = 0
   set @f_weightpd11 = 0
   set @f_weightpd12 = 0
   set @f_weightwk1 = 0
   set @f_weightwk2 = 0
   set @f_weightwk3 = 0
   set @f_weightwk4 = 0
   set @f_weightwk5 = 0
   set @f_skupd1 = 0
   set @f_skupd2 = 0
   set @f_skupd3 = 0
   set @f_skupd4 = 0
   set @f_skupd5 = 0
   set @f_skupd6 = 0
   set @f_skupd7 = 0
   set @f_skupd8 = 0
   set @f_skupd9 = 0
   set @f_skupd10 = 0
   set @f_skupd11 = 0
   set @f_skupd12 = 0
   set @f_skuwk1 = 0
   set @f_skuwk2 = 0
   set @f_skuwk3 = 0
   set @f_skuwk4 = 0
   set @f_skuwk5 = 0
   set @f_invpd1 = 0
   set @f_invpd2 = 0
   set @f_invpd3 = 0
   set @f_invpd4 = 0
   set @f_invpd5 = 0
   set @f_invpd6 = 0
   set @f_invpd7 = 0
   set @f_invpd8 = 0
   set @f_invpd9 = 0
   set @f_invpd10 = 0
   set @f_invpd11 = 0
   set @f_invpd12 = 0
   set @f_invwk1 = 0
   set @f_invwk2 = 0
   set @f_invwk3 = 0
   set @f_invwk4 = 0
   set @f_invwk5 = 0
   set @n_wk1 = 0
   set @n_wk2 = 0
   set @n_wk3 = 0
   set @n_wk4 = 0
   set @n_wk5 = 0
   -- end of initialization
   create table #temprec(
   storerkey NVARCHAR(15),
   skugroup NVARCHAR(10) null,
   au NVARCHAR(20), -- analyzing units
   pd1 float(8),
   pd2 float(8),
   pd3 float(8),
   pd4 float(8),
   pd5 float(8),
   pd6 float(8),
   pd7 float(8),
   pd8 float(8),
   pd9 float(8),
   pd10 float(8),
   pd11 float(8),
   pd12 float(8),
   total float(8),
   ytd float(8),
   wk1 float(8),
   wk2 float(8),
   wk3 float(8),
   wk4 float(8),
   wk5 float(8),
   mtd float(8)
   )
   set @n_pd1 = 0
   set @n_pd2 = 0
   set @n_pd3 = 0
   set @n_pd4 = 0
   set @n_pd5 = 0
   set @n_pd6 = 0
   set @n_pd7 = 0
   set @n_pd8 = 0
   set @n_pd9 = 0
   set @n_pd10 = 0
   set @n_pd11 = 0
   set @n_pd12 = 0
   set @n_year = datepart(year,getdate()) -- get current year
   set @n_current_month = datepart(month,getdate())
   declare rec_cur cursor FAST_FORWARD READ_ONLY
   for
   select a.storerkey, c.skugroup, a.receiptdate, d.casecnt, d.pallet ,c.stdnetwgt, b.qtyreceived, c.stdcube from receipt a(nolock), receiptdetail b(nolock), sku c(nolock), pack d(nolock)
   where a.receiptkey = b.receiptkey
   and b.sku = c.sku
   and c.packkey = d.packkey
   and datepart(year,a.receiptdate) = @n_year
   and a.storerkey between @c_fr_storerkey and @c_to_storerkey
   and a.receiptdate between @d_fr_receiptdate and @d_to_receiptdate
   and c.skugroup between @c_fr_skugroup and @c_to_skugroup
   order by a.storerkey, c.skugroup
   open rec_cur
   fetch next from rec_cur into @c_storerkey, @c_skugroup, @d_receiptdate, @f_casecnt, @f_pallet, @f_weight,@n_qtyreceived, @f_cube
   set @c_cur_storerkey = @c_storerkey
   set @c_pre_storerkey = @c_cur_storerkey
   set @c_cur_skugroup = @c_skugroup
   set @c_pre_skugroup = @c_cur_skugroup
   while (@@fetch_status=0)
   begin
      set @n_month = datepart(month,@d_receiptdate)
      if (@c_cur_storerkey = @c_pre_storerkey) and (@c_cur_skugroup = @c_pre_skugroup) -- if same storerkey and skugroup
      begin
         /***********************************************
         Get the qty for each month in the year
         *************************************************/
         if @n_month = 1
         set @n_pd1 = @n_pd1 + @n_qtyreceived
      else if @n_month = 2
         set @n_pd2 = @n_pd2 + @n_qtyreceived
      else if @n_month = 3
         set @n_pd3 = @n_pd3 + @n_qtyreceived
      else if @n_month = 4
         set @n_pd4 = @n_pd4 + @n_qtyreceived
      else if @n_month = 5
         set @n_pd5 = @n_pd5 + @n_qtyreceived
      else if @n_month = 6
         set @n_pd6 = @n_pd6 + @n_qtyreceived
      else if @n_month = 7
         set @n_pd7 = @n_pd7 + @n_qtyreceived
      else if @n_month = 8
         set @n_pd8 = @n_pd8 + @n_qtyreceived
      else if @n_month = 9
         set @n_pd9 = @n_pd9 + @n_qtyreceived
      else if @n_month = 10
         set @n_pd10 = @n_pd10 + @n_qtyreceived
      else if @n_month = 11
         set @n_pd11 = @n_pd11 + @n_qtyreceived
      else if @n_month = 12
         set @n_pd12 = @n_pd12 + @n_qtyreceived
         /********************************************************
         Get the qty for each week in the current month
         **********************************************************/
         if @n_month = @n_current_month
         if datepart(day,@d_receiptdate)>=1 and datepart(day,@d_receiptdate)<=7
         set @n_wk1 = @n_wk1 + @n_qtyreceived
      else if datepart(day,@d_receiptdate)>=8 and datepart(day,@d_receiptdate)<=14
         set @n_wk2 = @n_wk2 + @n_qtyreceived
      else if datepart(day,@d_receiptdate)>=15 and datepart(day,@d_receiptdate)<=21
         set @n_wk3 = @n_wk3 + @n_qtyreceived
      else if datepart(day,@d_receiptdate)>=22 and datepart(day,@d_receiptdate)<=28
         set @n_wk4 = @n_wk4 + @n_qtyreceived
      else
         set @n_wk5 = @n_wk5 + @n_qtyreceived
         /***********************************
         Process for WEIGHT analysizing unit
         ************************************/
         if @c_weight = "Y"
         begin
            if @n_pd1 <> 0
            set @f_weightpd1 = @f_weightpd1 + (@n_pd1*@f_weight)
            if @n_pd2 <> 0
            set @f_weightpd2 = @f_weightpd2 + (@n_pd2*@f_weight)
            if @n_pd3 <> 0
            set @f_weightpd3 = @f_weightpd3 + (@n_pd3*@f_weight)
            if @n_pd4 <> 0
            set @f_weightpd4 = @f_weightpd4 + (@n_pd4*@f_weight)
            if @n_pd5 <> 0
            set @f_weightpd5 = @f_weightpd5 + (@n_pd5*@f_weight)
            if @n_pd6 <> 0
            set @f_weightpd6 = @f_weightpd6 + (@n_pd6*@f_weight)
            if @n_pd7 <> 0
            set @f_weightpd7 = @f_weightpd7 + (@n_pd7*@f_weight)
            if @n_pd8 <> 0
            set @f_weightpd8 = @f_weightpd8 + (@n_pd8*@f_weight)
            if @n_pd9 <> 0
            set @f_weightpd9 = @f_weightpd9 + (@n_pd9*@f_weight)
            if @n_pd10 <> 0
            set @f_weightpd10 = @f_weightpd10 + (@n_pd10*@f_weight)
            if @n_pd11 <> 0
            set @f_weightpd11 = @f_weightpd11 + (@n_pd11*@f_weight)
            if @n_pd12 <> 0
            set @f_weightpd12 = @f_weightpd12 + (@n_pd12*@f_weight)
            -- get total for each week in the current month
            set @f_weightwk1 = @f_weightwk1 + (@n_wk1*@f_weight)
            set @f_weightwk2 = @f_weightwk2 + (@n_wk2*@f_weight)
            set @f_weightwk3 = @f_weightwk3 + (@n_wk3*@f_weight)
            set @f_weightwk4 = @f_weightwk4 + (@n_wk4*@f_weight)
            set @f_weightwk5 = @f_weightwk5 + (@n_wk5*@f_weight)
            -- get total (1st month/period up to the current month )for each month in the current year
            if @n_current_month = 1
            set @f_total_weight = @f_weightpd1
         else if @n_current_month = 2
            set @f_total_weight = @f_weightpd1 + @f_weightpd2
         else if @n_current_month = 3
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3
         else if @n_current_month = 4
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3 + @f_weightpd4
         else if @n_current_month = 5
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3 + @f_weightpd4 + @f_weightpd5
         else if @n_current_month = 6
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3 + @f_weightpd4 + @f_weightpd5 + @f_weightpd6
         else if @n_current_month = 7
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3 + @f_weightpd4 + @f_weightpd5 + @f_weightpd6 + @f_weightpd7
         else if @n_current_month = 8
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3 + @f_weightpd4 + @f_weightpd5 + @f_weightpd6 + @f_weightpd7 + @f_weightpd8
         else if @n_current_month = 9
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3 + @f_weightpd4 + @f_weightpd5 + @f_weightpd6 + @f_weightpd7 + @f_weightpd8 + @f_weightpd9
         else if @n_current_month = 10
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3 + @f_weightpd4 + @f_weightpd5 + @f_weightpd6 + @f_weightpd7 + @f_weightpd8 + @f_weightpd9 + @f_weightpd10
         else if @n_current_month = 11
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3 + @f_weightpd4 + @f_weightpd5 + @f_weightpd6 + @f_weightpd7 + @f_weightpd8 + @f_weightpd9 + @f_weightpd10 + @f_weightpd11
         else if @n_current_month = 12
            set @f_total_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3 + @f_weightpd4 + @f_weightpd5 + @f_weightpd6 + @f_weightpd7 + @f_weightpd8 + @f_weightpd9 + @f_weightpd10 + @f_weightpd11 + @f_weightpd12
         end
         /***********************************
         Process for PALLET analysizing unit
         ************************************/
         if @c_pallet = "Y"
         begin
            if @f_pallet<>0
            begin
               if @n_pd1 <> 0
               set @f_palletpd1 = @f_palletpd1 + (@n_pd1/@f_pallet)
               if @n_pd2 <> 0
               set @f_palletpd2 = @f_palletpd2 + (@n_pd2/@f_pallet)
               if @n_pd3 <> 0
               set @f_palletpd3 = @f_palletpd3 + (@n_pd3/@f_pallet)
               if @n_pd4 <> 0
               set @f_palletpd4 = @f_palletpd4 + (@n_pd4/@f_pallet)
               if @n_pd5 <> 0
               set @f_palletpd5 = @f_palletpd5 + (@n_pd5/@f_pallet)
               if @n_pd6 <> 0
               set @f_palletpd6 = @f_palletpd6 + (@n_pd6/@f_pallet)
               if @n_pd7 <> 0
               set @f_palletpd7 = @f_palletpd7 + (@n_pd7/@f_pallet)
               if @n_pd8 <> 0
               set @f_palletpd8 = @f_palletpd8 + (@n_pd8/@f_pallet)
               if @n_pd9 <> 0
               set @f_palletpd9 = @f_palletpd9 + (@n_pd9/@f_pallet)
               if @n_pd10 <> 0
               set @f_palletpd10 = @f_palletpd10 + (@n_pd10/@f_pallet)
               if @n_pd11 <> 0
               set @f_palletpd11 = @f_palletpd11 + (@n_pd11/@f_pallet)
               if @n_pd12 <> 0
               set @f_palletpd12 = @f_palletpd12 + (@n_pd12/@f_pallet)
               set @f_palletwk1 = @f_palletwk1 + (@n_wk1/@f_pallet)
               set @f_palletwk2 = @f_palletwk2 + (@n_wk2/@f_pallet)
               set @f_palletwk3 = @f_palletwk3 + (@n_wk3/@f_pallet)
               set @f_palletwk4 = @f_palletwk4 + (@n_wk4/@f_pallet)
               set @f_palletwk5 = @f_palletwk5 + (@n_wk5/@f_pallet)
               if @n_current_month = 1
               set @f_total_pallet = @f_palletpd1
            else if @n_current_month = 2
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2
            else if @n_current_month = 3
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3
            else if @n_current_month = 4
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3 + @f_palletpd4
            else if @n_current_month = 5
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3 + @f_palletpd4 + @f_palletpd5
            else if @n_current_month = 6
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3 + @f_palletpd4 + @f_palletpd5 + @f_palletpd6
            else if @n_current_month = 7
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3 + @f_palletpd4 + @f_palletpd5 + @f_palletpd6 + @f_palletpd7
            else if @n_current_month = 8
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3 + @f_palletpd4 + @f_palletpd5 + @f_palletpd6 + @f_palletpd7 + @f_palletpd8
            else if @n_current_month = 9
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3 + @f_palletpd4 + @f_palletpd5 + @f_palletpd6 + @f_palletpd7 + @f_palletpd8 + @f_palletpd9
            else if @n_current_month = 10
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3 + @f_palletpd4 + @f_palletpd5 + @f_palletpd6 + @f_palletpd7 + @f_palletpd8 + @f_palletpd9 + @f_palletpd10
            else if @n_current_month = 11
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3 + @f_palletpd4 + @f_palletpd5 + @f_palletpd6 + @f_palletpd7 + @f_palletpd8 + @f_palletpd9 + @f_palletpd10 + @f_palletpd11
            else if @n_current_month = 12
               set @f_total_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3 + @f_palletpd4 + @f_palletpd5 + @f_palletpd6 + @f_palletpd7 + @f_palletpd8 + @f_palletpd9 + @f_palletpd10 + @f_palletpd11 + @f_palletpd12
            end
         end
         /***********************************
         Process for CASE analysizing unit
         ************************************/
         if @c_case = "Y"
         begin
            if @f_casecnt <> 0
            begin
               if @n_pd1 <> 0
               set @f_casepd1 = @f_casepd1 + (@n_pd1/@f_casecnt)
               if @n_pd2 <> 0
               set @f_casepd2 = @f_casepd2 + (@n_pd2/@f_casecnt)
               if @n_pd3 <> 0
               set @f_casepd3 = @f_casepd3 + (@n_pd3/@f_casecnt)
               if @n_pd4 <> 0
               set @f_casepd4 = @f_casepd4 + (@n_pd4/@f_casecnt)
               if @n_pd5 <> 0
               set @f_casepd5 = @f_casepd5 + (@n_pd5/@f_casecnt)
               if @n_pd6 <> 0
               set @f_casepd6 = @f_casepd6 + (@n_pd6/@f_casecnt)
               if @n_pd7 <> 0
               set @f_casepd7 = @f_casepd7 + (@n_pd7/@f_casecnt)
               if @n_pd8 <> 0
               set @f_casepd8 = @f_casepd8 + (@n_pd8/@f_casecnt)
               if @n_pd9 <> 0
               set @f_casepd9 = @f_casepd9 + (@n_pd9/@f_casecnt)
               if @n_pd10 <> 0
               set @f_casepd10 = @f_casepd10 + (@n_pd10/@f_casecnt)
               if @n_pd11 <> 0
               set @f_casepd11 = @f_casepd11 + (@n_pd11/@f_casecnt)
               if @n_pd12 <> 0
               set @f_casepd12 = @f_casepd12 + (@n_pd12/@f_casecnt)
               set @f_casewk1 = @f_casewk1 + (@n_wk1/@f_casecnt)
               set @f_casewk2 = @f_casewk2 + (@n_wk2/@f_casecnt)
               set @f_casewk3 = @f_casewk3 + (@n_wk3/@f_casecnt)
               set @f_casewk4 = @f_casewk4 + (@n_wk4/@f_casecnt)
               set @f_casewk5 = @f_casewk5 + (@n_wk5/@f_casecnt)
               if @n_current_month = 1
               set @f_total_case = @f_casepd1
            else if @n_current_month = 2
               set @f_total_case = @f_casepd1 + @f_casepd2
            else if @n_current_month = 3
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3
            else if @n_current_month = 4
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3 + @f_casepd4
            else if @n_current_month = 5
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3 + @f_casepd4 + @f_casepd5
            else if @n_current_month = 6
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3 + @f_casepd4 + @f_casepd5 + @f_casepd6
            else if @n_current_month = 7
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3 + @f_casepd4 + @f_casepd5 + @f_casepd6 + @f_casepd7
            else if @n_current_month = 8
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3 + @f_casepd4 + @f_casepd5 + @f_casepd6 + @f_casepd7 + @f_casepd8
            else if @n_current_month = 9
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3 + @f_casepd4 + @f_casepd5 + @f_casepd6 + @f_casepd7 + @f_casepd8 + @f_casepd9
            else if @n_current_month = 10
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3 + @f_casepd4 + @f_casepd5 + @f_casepd6 + @f_casepd7 + @f_casepd8 + @f_casepd9 + @f_casepd10
            else if @n_current_month = 11
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3 + @f_casepd4 + @f_casepd5 + @f_casepd6 + @f_casepd7 + @f_casepd8 + @f_casepd9 + @f_casepd10 + @f_casepd11
            else if @n_current_month = 12
               set @f_total_case = @f_casepd1 + @f_casepd2 + @f_casepd3 + @f_casepd4 + @f_casepd5 + @f_casepd6 + @f_casepd7 + @f_casepd8 + @f_casepd9 + @f_casepd10 + @f_casepd11 + @f_casepd12
            end
         end
         /***********************************
         Process for CUBE analysizing unit
         ************************************/
         if @c_cube="Y"
         begin
            if @n_pd1 <> 0
            set @f_cubepd1 = @f_cubepd1 + (@n_pd1*@f_cube)
            if @n_pd2 <> 0
            set @f_cubepd2 = @f_cubepd2 + (@n_pd2*@f_cube)
            if @n_pd3 <> 0
            set @f_cubepd3 = @f_cubepd3 + (@n_pd3*@f_cube)
            if @n_pd4 <> 0
            set @f_cubepd4 = @f_cubepd4 + (@n_pd4*@f_cube)
            if @n_pd5 <> 0
            set @f_cubepd5 = @f_cubepd5 + (@n_pd5*@f_cube)
            if @n_pd6 <> 0
            set @f_cubepd6 = @f_cubepd6 + (@n_pd6*@f_cube)
            if @n_pd7 <> 0
            set @f_cubepd7 = @f_cubepd7 + (@n_pd7*@f_cube)
            if @n_pd8 <> 0
            set @f_cubepd8= @f_cubepd8 + (@n_pd8*@f_cube)
            if @n_pd9 <> 0
            set @f_cubepd9 = @f_cubepd9 + (@n_pd9*@f_cube)
            if @n_pd10 <> 0
            set @f_cubepd10 = @f_cubepd10+ (@n_pd10*@f_cube)
            if @n_pd11 <> 0
            set @f_cubepd11 = @f_cubepd11 + (@n_pd11*@f_cube)
            if @n_pd12 <> 0
            set @f_cubepd12 = @f_cubepd12 + (@n_pd12*@f_cube)
            set @f_cubewk1 = @f_cubewk1 + (@n_wk1*@f_cube)
            set @f_cubewk2 = @f_cubewk2 + (@n_wk2*@f_cube)
            set @f_cubewk3 = @f_cubewk3 + (@n_wk3*@f_cube)
            set @f_cubewk4 = @f_cubewk4 + (@n_wk4*@f_cube)
            set @f_cubewk5 = @f_cubewk5 + (@n_wk5*@f_cube)
            /*
            Get the total (total number of analysis units from the 1st period to the current month)
            */
            if @n_current_month = 1
            set @f_total_cube = @f_cubepd1
         else if @n_current_month = 2
            set @f_total_cube = @f_cubepd1 + @f_cubepd2
         else if @n_current_month = 3
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3
         else if @n_current_month = 4
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4
         else if @n_current_month = 5
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4+ @f_cubepd5
         else if @n_current_month = 6
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4+ @f_cubepd5+ @f_cubepd6
         else if @n_current_month = 7
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4+ @f_cubepd5+ @f_cubepd6 + @f_cubepd7
         else if @n_current_month = 8
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4+ @f_cubepd5+ @f_cubepd6 + @f_cubepd7 + @f_cubepd8
         else if @n_current_month = 9
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4+ @f_cubepd5+ @f_cubepd6 + @f_cubepd7 + @f_cubepd8 + @f_cubepd9
         else if @n_current_month = 10
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4+ @f_cubepd5+ @f_cubepd6 + @f_cubepd7 + @f_cubepd8 + @f_cubepd9 + @f_cubepd10
         else if @n_current_month = 11
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4+ @f_cubepd5+ @f_cubepd6 + @f_cubepd7 + @f_cubepd8 + @f_cubepd9 + @f_cubepd10 + @f_cubepd11
         else if @n_current_month = 12
            set @f_total_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4+ @f_cubepd5+ @f_cubepd6 + @f_cubepd7 + @f_cubepd8 + @f_cubepd9 + @f_cubepd10 + @f_cubepd11 + @f_cubepd12
         end
         set @n_qtyreceived = 0
         set @f_cube = 0
         set @f_casecnt = 0
         set @f_pallet = 0
      end
   else -- different storerkey and sku group (for grouping)
      begin
         /***********************************
         Process for WEIGHT analysizing unit
         ************************************/
         if @c_weight = "Y"
         begin
            if @n_current_month = 12
            set @f_ytd_weight = @f_total_weight
         else
            set @f_ytd_weight = @f_weightpd1 + @f_weightpd2 + @f_weightpd3+ @f_weightpd4 + @f_weightpd5 + @f_weightpd6 + @f_weightpd7 + @f_weightpd8 + @f_weightpd9 + @f_weightpd10 + @f_weightpd11 + @f_weightpd12
            set @f_mtd_weight = @f_weightwk1 + @f_weightwk2 + @f_weightwk3 + @f_weightwk4 + @f_weightwk5
            insert into #temprec
            values(@c_storerkey,
            @c_skugroup,
            "Weight",
            @f_weightpd1,
            @f_weightpd2,
            @f_weightpd3,
            @f_weightpd4,
            @f_weightpd5,
            @f_weightpd6,
            @f_weightpd7,
            @f_weightpd8,
            @f_weightpd9,
            @f_weightpd10,
            @f_weightpd11,
            @f_weightpd12,
            @f_total_weight,
            @f_ytd_weight,
            @f_weightwk1,
            @f_weightwk2,
            @f_weightwk3,
            @f_weightwk4,
            @f_weightwk5,
            @f_mtd_weight)
            set @f_weightpd1 = 0
            set @f_weightpd2 = 0
            set @f_weightpd3 = 0
            set @f_weightpd4 = 0
            set @f_weightpd5 = 0
            set @f_weightpd6 = 0
            set @f_weightpd7 = 0
            set @f_weightpd8 = 0
            set @f_weightpd9 = 0
            set @f_weightpd10 = 0
            set @f_weightpd11 = 0
            set @f_weightpd12 = 0
            set @f_total_weight = 0
            set @f_ytd_weight = 0
            set @f_weightwk1 = 0
            set @f_weightwk2 = 0
            set @f_weightwk3 = 0
            set @f_weightwk4 = 0
            set @f_weightwk5 = 0
            set @f_mtd_weight = 0
         end
         /***********************************
         Process for PALLET analysizing unit
         ************************************/
         if @c_pallet = "Y"
         begin
            if @n_current_month = 12
            set @f_ytd_pallet = @f_total_pallet
         else
            set @f_ytd_pallet = @f_palletpd1 + @f_palletpd2 + @f_palletpd3+ @f_palletpd4 + @f_palletpd5 + @f_palletpd6 + @f_palletpd7 + @f_palletpd8 + @f_palletpd9 + @f_palletpd10 + @f_palletpd11 + @f_palletpd12
            set @f_mtd_pallet = @f_palletwk1 + @f_palletwk2 + @f_palletwk3 + @f_palletwk4 + @f_palletwk5
            insert into #temprec
            values(@c_storerkey,
            @c_skugroup,
            "Pallet",
            @f_palletpd1,
            @f_palletpd2,
            @f_palletpd3,
            @f_palletpd4,
            @f_palletpd5,
            @f_palletpd6,
            @f_palletpd7,
            @f_palletpd8,
            @f_palletpd9,
            @f_palletpd10,
            @f_palletpd11,
            @f_palletpd12,
            @f_total_pallet,
            @f_ytd_pallet,
            @f_palletwk1,
            @f_palletwk2,
            @f_palletwk3,
            @f_palletwk4,
            @f_palletwk5,
            @f_mtd_pallet)
            set @f_palletpd1 = 0
            set @f_palletpd2 = 0
            set @f_palletpd3 = 0
            set @f_palletpd4 = 0
            set @f_palletpd5 = 0
            set @f_palletpd6 = 0
            set @f_palletpd7 = 0
            set @f_palletpd8 = 0
            set @f_palletpd9 = 0
            set @f_palletpd10 = 0
            set @f_palletpd11 = 0
            set @f_palletpd12 = 0
            set @f_total_pallet = 0
            set @f_ytd_pallet = 0
            set @f_palletwk1 = 0
            set @f_palletwk2 = 0
            set @f_palletwk3 = 0
            set @f_palletwk4 = 0
            set @f_palletwk5 = 0
            set @f_mtd_pallet = 0
         end
         /***********************************
         Process for CASE analysizing unit
         ************************************/
         if @c_case = "Y"
         begin
            if @n_current_month = 12
            set @f_ytd_case = @f_total_case
         else
            set @f_ytd_case = @f_casepd1 + @f_casepd2 + @f_casepd3+ @f_casepd4 + @f_casepd5 + @f_casepd6 + @f_casepd7 + @f_casepd8 + @f_casepd9 + @f_casepd10 + @f_casepd11 + @f_casepd12
            set @f_mtd_case = @f_casewk1 + @f_casewk2 + @f_casewk3 + @f_casewk4 + @f_casewk5
            insert into #temprec
            values(@c_storerkey,
            @c_skugroup,
            "Case",
            @f_casepd1,
            @f_casepd2,
            @f_casepd3,
            @f_casepd4,
            @f_casepd5,
            @f_casepd6,
            @f_casepd7,
            @f_casepd8,
            @f_casepd9,
            @f_casepd10,
            @f_casepd11,
            @f_casepd12,
            @f_total_case,
            @f_ytd_case,
            @f_casewk1,
            @f_casewk2,
            @f_casewk3,
            @f_casewk4,
            @f_casewk5,
            @f_mtd_case)
            set @f_casepd1 = 0
            set @f_casepd2 = 0
            set @f_casepd3 = 0
            set @f_casepd4 = 0
            set @f_casepd5 = 0
            set @f_casepd6 = 0
            set @f_casepd7 = 0
            set @f_casepd8 = 0
            set @f_casepd9 = 0
            set @f_casepd10 = 0
            set @f_casepd11 = 0
            set @f_casepd12 = 0
            set @f_total_case = 0
            set @f_ytd_case = 0
            set @f_casewk1 = 0
            set @f_casewk2 = 0
            set @f_casewk3 = 0
            set @f_casewk4 = 0
            set @f_casewk5 = 0
            set @f_mtd_case = 0
         end
         /***********************************
         Process for CUBE analysizing unit
         ************************************/
         if @c_cube = "Y"
         begin
            /*
            Get YTD
            */
            if @n_current_month = 12
            set @f_ytd_cube = @f_total_cube
         else
            set @f_ytd_cube = @f_cubepd1 + @f_cubepd2 + @f_cubepd3+ @f_cubepd4 + @f_cubepd5 + @f_cubepd6 + @f_cubepd7 + @f_cubepd8 + @f_cubepd9 + @f_cubepd10 + @f_cubepd11 + @f_cubepd12
            set @f_mtd_cube = @f_cubewk1 + @f_cubewk2 + @f_cubewk3 + @f_cubewk4 + @f_cubewk5
            insert into #temprec
            values(@c_storerkey,
            @c_skugroup,
            "M3",
            @f_cubepd1,
            @f_cubepd2,
            @f_cubepd3,
            @f_cubepd4,
            @f_cubepd5,
            @f_cubepd6,
            @f_cubepd7,
            @f_cubepd8,
            @f_cubepd9,
            @f_cubepd10,
            @f_cubepd11,
            @f_cubepd12,
            @f_total_cube,
            @f_ytd_cube,
            @f_cubewk1,
            @f_cubewk2,
            @f_cubewk3,
            @f_cubewk4,
            @f_cubewk5,
            @f_mtd_cube)
            set @f_cubepd1 = 0
            set @f_cubepd2 = 0
            set @f_cubepd3 = 0
            set @f_cubepd4 = 0
            set @f_cubepd5 = 0
            set @f_cubepd6 = 0
            set @f_cubepd7 = 0
            set @f_cubepd8 = 0
            set @f_cubepd9 = 0
            set @f_cubepd10 = 0
            set @f_cubepd11 = 0
            set @f_cubepd12 = 0
            set @f_total_cube = 0
            set @f_ytd_cube = 0
            set @f_cubewk1 = 0
            set @f_cubewk2 = 0
            set @f_cubewk3 = 0
            set @f_cubewk4 = 0
            set @f_cubewk5 = 0
            set @f_mtd_cube = 0
         end
      end
      set @c_pre_storerkey = @c_storerkey
      set @c_pre_skugroup = @c_skugroup
      fetch next from rec_cur into @c_storerkey, @c_skugroup, @d_receiptdate, @f_casecnt, @f_pallet, @f_weight, @n_qtyreceived, @f_cube
      set @c_cur_storerkey = @c_storerkey
      set @c_cur_skugroup = @c_skugroup
   end -- end of looping each record
   /**********************************************************
   Process for NoCommodity (Number of SKUs) analysizing unit
   ***********************************************************/
   if @c_nosku = "Y"
   begin
      while @n_month_cnt < 13 -- get no of skus for each month
      begin
         declare nosku_cur cursor FAST_FORWARD READ_ONLY
         for
         select a.storerkey,c.skugroup,count(distinct b.sku)
         from receipt a(NOLOCK), receiptdetail b(NOLOCK), sku c(NOLOCK)
         where datepart(year,a.receiptdate) = @n_year
         and datepart(month,a.receiptdate) = @n_month_cnt
         and a.receiptkey = b.receiptkey
         and b.sku = c.sku
         group by a.storerkey, c.skugroup
         order by a.storerkey, c.skugroup
         open nosku_cur
         fetch next from nosku_cur into @c_storerkey, @c_skugroup, @f_nosku
         while (@@fetch_status=0)
         begin
            if @n_month_cnt = 1
            set @f_skupd1 = @f_skupd1 + @f_nosku
            if @n_month_cnt = 2
            set @f_skupd2 = @f_skupd2 + @f_nosku
            if @n_month_cnt = 3
            set @f_skupd3 = @f_skupd3 + @f_nosku
            if @n_month_cnt = 4
            set @f_skupd4 = @f_skupd4 + @f_nosku
            if @n_month_cnt = 5
            set @f_skupd5 = @f_skupd5 + @f_nosku
            if @n_month_cnt = 6
            set @f_skupd6 = @f_skupd6 + @f_nosku
            if @n_month_cnt = 7
            set @f_skupd7 = @f_skupd7 + @f_nosku
            if @n_month_cnt = 8
            set @f_skupd8 = @f_skupd8 + @f_nosku
            if @n_month_cnt = 9
            set @f_skupd9 = @f_skupd9 + @f_nosku
            if @n_month_cnt = 10
            set @f_skupd10 = @f_skupd10 + @f_nosku
            if @n_month_cnt = 11
            set @f_skupd11 = @f_skupd12 + @f_nosku
            if @n_month_cnt = 12
            set @f_skupd12 = @f_skupd12 + @f_nosku
            -- get no of SKUs per week
            select @f_skuwk1=count(distinct b.sku) -- get 1st week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>=1 and datepart(day,a.receiptdate)<=7
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            select @f_skuwk2=count(distinct b.sku) -- get 2nd week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>=8 and datepart(day,a.receiptdate)<=14
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            select @f_skuwk3=count(distinct b.sku) -- get 3rd week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>=15 and datepart(day,a.receiptdate)<=21
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            select @f_skuwk4=count(distinct b.sku) -- get 4th week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>=22 and datepart(day,a.receiptdate)<=28
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            select @f_skuwk5=count(distinct b.sku) -- get 5th week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>28
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            -- get TOTAL (from 1st period to the current period)
            if @n_current_month = 1
            set @f_total_sku = @f_skupd1
         else if @n_current_month = 2
            set @f_total_sku = @f_skupd1 + @f_skupd2
         else if @n_current_month = 3
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3
         else if @n_current_month = 4
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3 + @f_skupd4
         else if @n_current_month = 5
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3 + @f_skupd4 + @f_skupd5
         else if @n_current_month = 6
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3 + @f_skupd4 + @f_skupd5 + @f_skupd6
         else if @n_current_month = 7
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3 + @f_skupd4 + @f_skupd5 + @f_skupd6 + @f_skupd7
         else if @n_current_month = 8
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3 + @f_skupd4 + @f_skupd5 + @f_skupd6 + @f_skupd7 + @f_skupd8
         else if @n_current_month = 9
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3 + @f_skupd4 + @f_skupd5 + @f_skupd6 + @f_skupd7 + @f_skupd8 + @f_skupd9
         else if @n_current_month = 10
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3 + @f_skupd4 + @f_skupd5 + @f_skupd6 + @f_skupd7 + @f_skupd8 + @f_skupd9 + @f_skupd10
         else if @n_current_month = 11
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3 + @f_skupd4 + @f_skupd5 + @f_skupd6 + @f_skupd7 + @f_skupd8 + @f_skupd9 + @f_skupd10 + @f_skupd11
         else if @n_current_month = 12
            set @f_total_sku = @f_skupd1 + @f_skupd2 + @f_skupd3 + @f_skupd4 + @f_skupd5 + @f_skupd6 + @f_skupd7 + @f_skupd8 + @f_skupd9 + @f_skupd10 + @f_skupd11 + @f_skupd12
            if @n_current_month = 12
            set @f_ytd_sku = @f_total_sku
         else
            set @f_ytd_sku = @f_skupd1 + @f_skupd2 + @f_skupd3+ @f_skupd4 + @f_skupd5 + @f_skupd6 + @f_skupd7 + @f_skupd8 + @f_skupd9 + @f_skupd10 + @f_skupd11 + @f_skupd12
            set @f_mtd_sku = @f_skuwk1 + @f_skuwk2 + @f_skuwk3
            + @f_skuwk4 + @f_skuwk5
            insert into #temprec
            values(@c_storerkey,
            @c_skugroup,
            "NoCommodity",
            @f_skupd1,
            @f_skupd2,
            @f_skupd3,
            @f_skupd4,
            @f_skupd5,
            @f_skupd6,
            @f_skupd7,
            @f_skupd8,
            @f_skupd9,
            @f_skupd10,
            @f_skupd11,
            @f_skupd12,
            @f_total_sku,
            @f_ytd_sku,
            @f_skuwk1,
            @f_skuwk2,
            @f_skuwk3,
            @f_skuwk4,
            @f_skuwk5,
            @f_mtd_sku)
            set @f_skupd1 = 0
            set @f_skupd2 = 0
            set @f_skupd3 = 0
            set @f_skupd4 = 0
            set @f_skupd5 = 0
            set @f_skupd6 = 0
            set @f_skupd7 = 0
            set @f_skupd8 = 0
            set @f_skupd9 = 0
            set @f_skupd10 = 0
            set @f_skupd11 = 0
            set @f_skupd12 = 0
            set @f_total_sku = 0
            set @f_ytd_sku = 0
            set @f_skuwk1 = 0
            set @f_skuwk2 = 0
            set @f_skuwk3 = 0
            set @f_skuwk4 = 0
            set @f_skuwk5 = 0
            set @f_mtd_sku = 0
            fetch next from nosku_cur into @c_storerkey, @c_skugroup, @f_nosku
         end
         close nosku_cur
         deallocate nosku_cur
         set @n_month_cnt = @n_month_cnt + 1
      end
   end -- end of process of NoCommodity
   /**********************************************************
   Process for Invoice (Number of Invoices) analysizing unit
   ***********************************************************/
   if @c_noinv = "Y"
   begin
      set @n_month_cnt = 1
      set @c_storerkey = ""
      set @c_skugroup = ""
      set @f_skupd1 = 0
      set @f_skupd2 = 0
      set @f_skupd3 = 0
      set @f_skupd4 = 0
      set @f_skupd5 = 0
      set @f_skupd6 = 0
      set @f_skupd7 = 0
      set @f_skupd8 = 0
      set @f_skupd9 = 0
      set @f_skupd10 = 0
      set @f_skupd11 = 0
      set @f_skupd12 = 0
      set @f_total_sku = 0
      set @f_ytd_sku = 0
      set @f_skuwk1 = 0
      set @f_skuwk2 = 0
      set @f_skuwk3 = 0
      set @f_skuwk4 = 0
      set @f_skuwk5 = 0
      set @f_mtd_sku = 0
      while @n_month_cnt < 13 -- get no of invoices for each month
      begin
         declare noinv_cur cursor FAST_FORWARD READ_ONLY
         for
         select a.storerkey,c.skugroup,count(distinct a.pokey)
         from receipt a(NOLOCK), receiptdetail b(NOLOCK), sku c(NOLOCK)
         where datepart(year,a.receiptdate) = @n_year
         and datepart(month,a.receiptdate) = @n_month_cnt
         and a.receiptkey = b.receiptkey
         and b.sku = c.sku
         group by a.storerkey, c.skugroup
         order by a.storerkey, c.skugroup
         open noinv_cur
         fetch next from noinv_cur into @c_storerkey, @c_skugroup, @f_noinv
         while (@@fetch_status=0)
         begin
            select @c_storerkey, @c_skugroup,@f_noinv
            if @n_month_cnt = 1
            set @f_invpd1 = @f_invpd1 + @f_noinv
            if @n_month_cnt = 2
            set @f_invpd2 = @f_invpd2 + @f_noinv
            if @n_month_cnt = 3
            set @f_invpd3 = @f_invpd3 + @f_noinv
            if @n_month_cnt = 4
            set @f_invpd4 = @f_invpd4 + @f_noinv
            if @n_month_cnt = 5
            set @f_invpd5 = @f_invpd5 + @f_noinv
            if @n_month_cnt = 6
            set @f_invpd6 = @f_invpd6 + @f_noinv
            if @n_month_cnt = 7
            set @f_invpd7 = @f_invpd7 + @f_noinv
            if @n_month_cnt = 8
            set @f_invpd8 = @f_invpd8 + @f_noinv
            if @n_month_cnt = 9
            set @f_invpd9 = @f_invpd9 + @f_noinv
            if @n_month_cnt = 10
            set @f_invpd10 = @f_invpd10 + @f_noinv
            if @n_month_cnt = 11
            set @f_invpd11 = @f_invpd12 + @f_noinv
            if @n_month_cnt = 12
            set @f_invpd12 = @f_invpd12 + @f_noinv
            -- get no of SKUs per week
            select @f_invwk1=count(distinct a.pokey) -- get 1st week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>=1 and datepart(day,a.receiptdate)<=7
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            select @f_invwk2=count(distinct a.pokey) -- get 2nd week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>=8 and datepart(day,a.receiptdate)<=14
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            select @f_invwk3=count(distinct a.pokey) -- get 3rd week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>=15 and datepart(day,a.receiptdate)<=21
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            select @f_invwk4=count(distinct a.pokey) -- get 4th week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>=22 and datepart(day,a.receiptdate)<=28
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            select @f_invwk5=count(distinct a.pokey) -- get 5th week
            from receipt a(nolock), receiptdetail b(nolock), sku c(nolock)
            where datepart(year,a.receiptdate) = @n_year
            and datepart(month,a.receiptdate) = @n_current_month
            and datepart(day,a.receiptdate)>28
            and a.storerkey = @c_storerkey
            and c.skugroup = @c_skugroup
            and a.receiptkey = b.receiptkey
            and b.sku = c.sku
            -- get TOTAL (from 1st period to the current period)
            if @n_current_month = 1
            set @f_total_inv = @f_invpd1
         else if @n_current_month = 2
            set @f_total_inv = @f_invpd1 + @f_invpd2
         else if @n_current_month = 3
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3
         else if @n_current_month = 4
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3 + @f_invpd4
         else if @n_current_month = 5
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3 + @f_invpd4 + @f_invpd5
         else if @n_current_month = 6
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3 + @f_invpd4 + @f_invpd5 + @f_invpd6
         else if @n_current_month = 7
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3 + @f_invpd4 + @f_invpd5 + @f_invpd6 + @f_invpd7
         else if @n_current_month = 8
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3 + @f_invpd4 + @f_invpd5 + @f_invpd6 + @f_invpd7 + @f_invpd8
         else if @n_current_month = 9
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3 + @f_invpd4 + @f_invpd5 + @f_invpd6 + @f_invpd7 + @f_invpd8 + @f_invpd9
         else if @n_current_month = 10
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3 + @f_invpd4 + @f_invpd5 + @f_invpd6 + @f_invpd7 + @f_invpd8 + @f_invpd9 + @f_invpd10
         else if @n_current_month = 11
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3 + @f_invpd4 + @f_invpd5 + @f_invpd6 + @f_invpd7 + @f_invpd8 + @f_invpd9 + @f_invpd10 + @f_invpd11
         else if @n_current_month = 12
            set @f_total_inv = @f_invpd1 + @f_invpd2 + @f_invpd3 + @f_invpd4 + @f_invpd5 + @f_invpd6 + @f_invpd7 + @f_invpd8 + @f_invpd9 + @f_invpd10 + @f_invpd11 + @f_invpd12
            if @n_current_month = 12
            set @f_ytd_inv = @f_total_inv
         else
            set @f_ytd_inv = @f_invpd1 + @f_invpd2 + @f_invpd3+ @f_invpd4 + @f_invpd5 + @f_invpd6 + @f_invpd7 + @f_invpd8 + @f_invpd9 + @f_invpd10 + @f_invpd11 + @f_invpd12
            set @f_mtd_inv = @f_invwk1 + @f_invwk2 + @f_invwk3 + @f_invwk4 + @f_invwk5
            insert into #temprec
            values(@c_storerkey,
            @c_skugroup,
            "Invoice",
            @f_invpd1,
            @f_invpd2,
            @f_invpd3,
            @f_invpd4,
            @f_invpd5,
            @f_invpd6,
            @f_invpd7,
            @f_invpd8,
            @f_invpd9,
            @f_invpd10,
            @f_invpd11,
            @f_invpd12,
            @f_total_inv,
            @f_ytd_inv,
            @f_invwk1,
            @f_invwk2,
            @f_invwk3,
            @f_invwk4,
            @f_invwk5,
            @f_mtd_inv)
            set @c_storerkey=""
            set @c_skugroup = 0
            set @f_noinv = 0
            set @f_invpd1 = 0
            set @f_invpd2 = 0
            set @f_invpd3 = 0
            set @f_invpd4 = 0
            set @f_invpd5 = 0
            set @f_invpd6 = 0
            set @f_invpd7 = 0
            set @f_invpd8 = 0
            set @f_invpd9 = 0
            set @f_invpd10 = 0
            set @f_invpd11 = 0
            set @f_invpd12 = 0
            set @f_total_inv = 0
            set @f_ytd_inv = 0
            set @f_invwk1 = 0
            set @f_invwk2 = 0
            set @f_invwk3 = 0
            set @f_invwk4 = 0
            set @f_invwk5 = 0
            set @f_mtd_inv = 0
            fetch next from noinv_cur into @c_storerkey, @c_skugroup, @f_noinv
         end
         close noinv_cur
         deallocate noinv_cur
         set @n_month_cnt = @n_month_cnt + 1
      end
   end -- end of process of Invoice
   select storerkey,
   skugroup,
   au,
   sum(pd1) pd1,
   sum(pd2) pd2,
   sum(pd3) pd3,
   sum(pd4) pd4,
   sum(pd5) pd5,
   sum(pd6) pd6,
   sum(pd7) pd7,
   sum(pd8) pd8,
   sum(pd9) pd9,
   sum(pd10) pd10,
   sum(pd11) pd11,
   sum(pd12) pd12,
   sum(total) total,
   sum(ytd) ytd,
   sum(wk1) wk1,
   sum(wk2) wk2,
   sum(wk3) wk3,
   sum(wk4) wk4,
   sum(wk5) wk5,
   sum(mtd) mtd
   from #temprec
   group by storerkey, skugroup, au
   order by storerkey, skugroup, au
   drop table #temprec
   close rec_cur
   deallocate rec_cur
end -- end of stored procedure

GO