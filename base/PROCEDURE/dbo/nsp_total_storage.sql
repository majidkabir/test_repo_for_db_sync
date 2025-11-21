SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_total_storage                                  */
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

CREATE PROC [dbo].[nsp_total_storage](
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

   declare @d_fr_date datetime,
   @d_to_date datetime,
   @n_dateapart int,
   @n_start_date int,
   @d_cur_date datetime,
   @c_storerkey NVARCHAR(15),
   @c_sku NVARCHAR(20),
   @n_qtystorage int,
   @f_casecnt float(8),
   @f_pallet float(8),
   @n_casestorage int,
   @n_palletstorage int
   set @n_start_date = 0
   create table #result(
   actdate datetime,
   storerkey NVARCHAR(15),
   sku NVARCHAR(15) null,
   skustorage int null,
   qtystorage int null,
   casestorage int null,
   palletstorage int null
   )
   set @n_dateapart = datediff(day,@datefrom, @dateto)
   set @d_cur_date = @datefrom
   while (@n_start_date <= @n_dateapart)
   begin
      declare cur1 cursor FAST_FORWARD READ_ONLY
      for
      select storerkey, sku, sum(qty)
      from itrn (nolock)
      where adddate >= (select Convert( datetime, @datefrom ))
      and adddate < (select DateAdd( day, 1, Convert( datetime,@dateto ) ) )
      and storerkey >= @c_from_storerkey
      and storerkey <= @c_to_storerkey
      group by storerkey, sku
      open cur1
      fetch next from cur1 into @c_storerkey, @c_sku, @n_qtystorage
      while (@@fetch_status=0)
      begin
         select @f_casecnt = isnull(b.casecnt,1),
         @f_pallet  = isnull(b.pallet,1)
         from sku a, pack b
         where a.packkey = b.packkey
         and a.sku = @c_sku
         and a.storerkey = @c_storerkey
         if @f_casecnt = 0
         set @f_casecnt = 1
         if @f_pallet = 0
         set @f_pallet = 1
         if @n_qtystorage >= @f_casecnt
         set @n_casestorage = convert(integer,@n_qtystorage/@f_casecnt)
      else
         set @n_casestorage = 0
         if @n_qtystorage >= @f_pallet
         set @n_palletstorage = convert(integer,@n_qtystorage/@f_pallet)
      else
         set @n_palletstorage = 0
         insert into #result
         values(@d_cur_date,@c_storerkey, @c_sku, 0,@n_qtystorage,@n_casestorage,@n_palletstorage)
         fetch next from cur1 into @c_storerkey, @c_sku, @n_qtystorage
      end
      close cur1
      deallocate cur1
      set @n_start_date = @n_start_date + 1
      set @d_cur_date = dateadd(day,1,@d_cur_date)
   end
   select * from #result
   drop table #result
end

GO