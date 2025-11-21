SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_Total_so_despatch_Rpt                          */
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

CREATE PROC [dbo].[nsp_Total_so_despatch_Rpt](
@c_from_storerkey NVARCHAR(15),
@c_to_storerkey NVARCHAR(15),
@datefrom datetime,
@dateto datetime
)
as
begin
   /**
   Author : Jacob
   Date   : 07 Feb 2001
   Description :

   (1) a temporary table named #report1 is created
   (2) actually 2 types of dates involved in this report, ADDDATE in Orders and EDITDATE in MBOL
   (3) In #report1, column SO_Act_Type indicates the date type. "Add" means AddDate from Orders. "Ship"
   means EditDate from MBOL.
   (4) Records with ONLY AcDate, Storerkey, and SO_Act_type are FIRST inserted. The rest of the columns are
   empty in the first place.
   (5) Each column, for example SO Created, SO Despatch,...etc, has it's own SQL statements to retrieve the quantity.
   Right after each SQL SELECT statement, there is an UPDATE statement to update the quantity back to #report1 table
   (6) The last SQL statement, which is the output of the report, is the SUM of the various quantity
   REGARDLESS OF their SO_Act_Type. SO_Act_type is just a field used for the UPDATE statements so that it will not update
   the wrong records because, GENERALLY, there are 2 types of records. One is the record retrieved by using AddDate from=
   Orders and another one using EditDate from MBOL.

   **/

   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_acdate NVARCHAR(10),
   @d_fr_acdate datetime,
   @d_to_acdate datetime,
   @c_storerkey NVARCHAR(15),
   @n_so_created int,
   @n_mbol_shipped int,
   @n_so_despatch int,
   @n_soline_despatch int,
   @n_cust_despatch int,
   @n_sku_despatch int,
   @n_qty_despatch int,
   @n_qty_shipped int,
   @f_case_despatch float(8),
   @f_pallet_despatch float(8),
   @f_weight_despatch float(8),
   @f_cube_despatch float(8),
   @n_qty_received int,
   @c_packkey NVARCHAR(10),
   @f_weight float(8),
   @f_cube float(8),
   @f_casecnt float(8),
   @f_pallet float(8)



   create table #report1(
   acdate NVARCHAR(10),
   storerkey NVARCHAR(15),
   so_created int null,
   mbol_shipped int null,
   so_despatch int null,
   soline_despatch int null,
   cust_despatch int null,
   sku_despatch int null,
   qty_despatch int null,
   case_despatch float(8) null,
   pallet_despatch float(8) null,
   weight_despatch float(8) null,
   cube_despatch float(8) null,
   SO_Act_Type NVARCHAR(20)
   )


   -- create entries of SO added
   declare cur1 cursor FAST_FORWARD READ_ONLY
   for
   select distinct convert(char(10),adddate,103), storerkey
   from orders
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
   -- end of SO added


   -- create entries for SO shipped
   declare cur1 cursor FAST_FORWARD READ_ONLY
   for
   select distinct convert(char(10),a.editdate,103), b.storerkey
   from mboldetail a (nolock), orders b (nolock), mbol c (nolock)
   where a.orderkey = b.orderkey
   and a.mbolkey = c.mbolkey
   and a.editdate >= (select Convert( datetime, @datefrom ))
   and a.editdate < (select DateAdd( day, 1, Convert( datetime, @dateto ) ) )
   and b.orderkey >= @c_from_storerkey
   and b.storerkey <= @c_to_storerkey
   and c.status="9"


   open cur1

   fetch next from cur1 into @c_acdate, @c_storerkey

   while (@@fetch_status=0)
   begin
      insert into #report1(acdate, storerkey,so_act_type)
      values(@c_acdate, @c_storerkey,"Ship")

      fetch next from cur1 into @c_acdate, @c_storerkey
   end


   close cur1
   deallocate cur1
   -- end of SO shipped




   declare cur2 cursor FAST_FORWARD READ_ONLY
   for
   select acdate, storerkey from #report1



   open cur2

   fetch next from cur2 into @c_acdate, @c_storerkey

   while (@@fetch_status=0)
   begin
      --get number of SO created
      select @n_so_created=count(orderkey)
      from orders (nolock)
      where convert(char(10),adddate,103) = @c_acdate
      and storerkey = @c_storerkey

      update #report1
      set so_created = @n_so_created
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Add"


      -- get number of MBOL shipped
      select @n_mbol_shipped=count(distinct a.mbolkey)
      from mboldetail a (nolock), mbol b (nolock), orders c (nolock)
      where convert(char(10),a.editdate,103) = @c_acdate
      and a.mbolkey = b.mbolkey
      and a.orderkey = c.orderkey
      and c.storerkey = @c_storerkey
      and b.status="9"


      update #report1
      set mbol_shipped = @n_mbol_shipped
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Ship"


      -- get number of SO despatch
      select @n_so_despatch=count(orderkey)
      from orders (nolock)
      where convert(char(10),adddate,103) = @c_acdate
      and storerkey = @c_storerkey
      and status="9"

      update #report1
      set so_despatch = @n_so_despatch
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Ship"

      -- get number of SO line despatch
      select @n_soline_despatch=count(*)
      from orderdetail (nolock)
      where convert(char(10),adddate,103) = @c_acdate
      and storerkey = @c_storerkey
      and status="9"

      update #report1
      set soline_despatch = @n_soline_despatch
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Ship"

      -- get number of customers despatch
      select @n_cust_despatch=count(distinct storerkey)
      from orders(nolock)
      where convert(char(10),adddate,103) = @c_acdate
      and storerkey = @c_storerkey
      and status="9"

      update #report1
      set cust_despatch = @n_cust_despatch
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Ship"

      -- get number of SKUs despatch
      select @n_sku_despatch=count(distinct sku)
      from orderdetail (nolock)
      where convert(char(10),adddate,103) = @c_acdate
      and storerkey = @c_storerkey
      and status="9"

      update #report1
      set sku_despatch = @n_sku_despatch
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Ship"

      -- get qty despatch
      select @n_qty_despatch=sum(shippedqty)
      from orderdetail (nolock)
      where convert(char(10),adddate,103) = @c_acdate
      and storerkey = @c_storerkey
      and status="9"

      update #report1
      set qty_despatch = isnull(@n_qty_despatch,0)
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Ship"

      set @f_casecnt = 0
      set @f_pallet = 0
      set @f_weight_despatch = 0
      set @f_cube_despatch = 0
      set @f_case_despatch = 0
      set @f_pallet_despatch = 0

      -- this cursor is used to get case count, pallet count, weight and cube
      declare cur3 cursor FAST_FORWARD READ_ONLY
      for
      select b.shippedqty, c.packkey, b.shippedqty*c.stdnetwgt, b.shippedqty*c.stdcube
      from orderdetail b (nolock), sku c (nolock), pack d (nolock)
      where b.sku = c.sku
      and c.packkey = d.packkey
      and convert(char(10),b.editdate,103) = @c_acdate
      and b.storerkey = @c_storerkey

      open cur3

      fetch next from cur3 into @n_qty_shipped, @c_packkey, @f_weight, @f_cube

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
         set @f_case_despatch = @f_case_despatch + (isnull(@n_qty_shipped,0)/isnull(@f_casecnt,1))

         -- get pallet receipt
         set @f_pallet_despatch = @f_pallet_despatch + (isnull(@n_qty_shipped,0)/isnull(@f_pallet,1))

         -- get weight receipt
         set @f_weight_despatch = @f_weight_despatch + @f_weight

         -- get cube receipt
         set @f_cube_despatch = @f_cube_despatch + @f_cube

         fetch next from cur3 into @n_qty_shipped, @c_packkey, @f_weight, @f_cube
      end

      update #report1
      set case_despatch = @f_case_despatch,
      pallet_despatch = @f_pallet_despatch,
      weight_despatch = @f_weight_despatch,
      cube_despatch = @f_cube_despatch
      where acdate = @c_acdate
      and storerkey = @c_storerkey
      and so_act_type = "Ship"

      close cur3
      deallocate cur3

      fetch next from cur2 into @c_acdate, @c_storerkey
   end

   close cur2
   deallocate cur2


   select acdate,
   storerkey,
   isnull(sum(so_created),0),
   isnull(sum(so_despatch),0),
   isnull(sum(soline_despatch),0),
   isnull(sum(cust_despatch),0),
   isnull(sum(sku_despatch),0),
   isnull(sum(qty_despatch),0),
   isnull(cast(round(sum(case_despatch),0) as int),0),
   isnull(cast(round(sum(pallet_despatch),0) as int),0),
   isnull(cast(round(sum(weight_despatch),0)as int),0),
   isnull(cast(round(sum(cube_despatch),0) as int ),0)
   from #report1
   group by acdate, storerkey
   order by acdate, storerkey

   drop table #report1

end -- end of stored procedure

GO