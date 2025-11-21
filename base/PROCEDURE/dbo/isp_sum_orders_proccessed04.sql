SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCedure [dbo].[isp_sum_orders_proccessed04](
    @c_storerkey NVARCHAR(15),
    @c_date_start NVARCHAR(10),
    @c_date_end NVARCHAR(10)
 )
 as
 begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 declare @n_ordline_no1 int,
         @n_ordline_no2 int,
         @n_ord_no1 int,
         @n_ord_no2 int,
         @c_type NVARCHAR(10),
         @n_willcall1 int,
         @n_willcall2 int,
         @n_norm1 int,
         @n_norm2 int,
         @n_critical1 int,
         @n_critical2 int,
         @n_export1 int,
         @n_export2 int,
         @n_success int,
         @n_failure int,
         @n_due_orders int,
         @c_company NVARCHAR(45),
         @n_sum_ordline_no int,
         @n_sum_ord_no int,
         @n_sum_willcall int,
         @n_sum_norm int,
         @n_sum_critical int,
         @n_sum_export int,
         @c_type_descr NVARCHAR(250)
 select @n_willcall1 = 0,
        @n_willcall2 = 0,
        @n_norm1 = 0,
        @n_norm2 = 0,
        @n_critical1 = 0,
        @n_critical2 = 0,
        @n_export1 = 0,
        @n_export2 = 0,
        @n_sum_ordline_no = 0,
        @n_sum_ord_no = 0,
        @n_sum_willcall = 0,
        @n_sum_norm = 0,
        @n_sum_critical = 0,
        @n_sum_export = 0
 select @c_company=company
 from storer (nolock)
 where storerkey = @c_storerkey
 create table #result(
    type_descr NVARCHAR(250) null,
    company NVARCHAR(45) null,
    ordline_no int null,
    ord_no int null,
    willcall int null,
    norm int null,
    critical int null,
    export int null
 )
 declare cur1 cursor FAST_FORWARD READ_ONLY
 for
 select distinct type from orders(nolock)
 where storerkey = @c_storerkey
 open cur1
 fetch next from cur1 into @c_type
 while (@@fetch_status=0)
    begin
       select @n_ordline_no1=count(*) 
       from orders a (nolock),
       orderdetail b (nolock)
       where a.orderkey = b.orderkey
       and a.storerkey = @c_storerkey
       and a.type = @c_type
       and b.status = '9'
 --      and a.orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and a.orderdate >= convert(datetime, @c_date_start)
 			and a.orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       select @n_ordline_no2=count(*) 
       from orders a (nolock),
       orderdetail b (nolock)
       where a.orderkey = b.orderkey
       and a.storerkey = @c_storerkey
       and a.type = @c_type
       and a.mbolkey=''
 --      and a.orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and a.orderdate >= convert(datetime, @c_date_start)
 			and a.orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       set @n_sum_ordline_no = @n_ordline_no1 + @n_ordline_no2
       select @n_ord_no1=count(*)
       from orders(nolock)
       where storerkey = @c_storerkey
       and type = @c_type
       and status = '9'
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       select @n_ord_no2=count(*)
       from orders(nolock)
       where storerkey = @c_storerkey
       and type = @c_type
       and mbolkey = ''
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       set @n_sum_ord_no = @n_ord_no1 + @n_ord_no2
       select @n_willcall1=count(*)
       from orders(nolock)
       where storerkey = @c_storerkey
       and type = @c_type
       and status = '9'
       and priority = '10' -- "will call" priority
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       select @n_willcall2=count(*)
       from orders(nolock)
 where storerkey = @c_storerkey
       and type = @c_type
       and mbolkey = ''
       and priority = '10' -- "will call" priority
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       set @n_sum_willcall = @n_willcall1 + @n_willcall2
       select @n_norm1=count(*)
       from orders(nolock)
       where storerkey = @c_storerkey
       and type = @c_type
       and status = '9'
       and priority = '50' -- "normal" priority
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       select @n_norm2=count(*)
       from orders(nolock)
       where storerkey = @c_storerkey
       and type = @c_type
       and mbolkey = ''
       and priority = '50' -- "normal" priority
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       set @n_sum_norm = @n_norm1 + @n_norm2
       select @n_critical1=count(*)
       from orders(nolock)
       where storerkey = @c_storerkey
       and type = @c_type
       and status = '9'
       and priority = '30' -- "critical" priority
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       select @n_critical2=count(*)
       from orders(nolock)
       where storerkey = @c_storerkey
       and type = @c_type
       and mbolkey = ''
       and priority = '30' -- "critical" priority
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       set @n_sum_critical = @n_critical1 + @n_critical2
       select @n_export1=count(*)
       from orders(nolock)
       where storerkey = @c_storerkey
       and type = @c_type
       and status = '9'
       and priority = 'EP' -- "export" priority
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       select @n_export2=count(*)
       from orders(nolock)
       where storerkey = @c_storerkey
       and type = @c_type
       and mbolkey = ''
       and priority = 'EP' -- "export" priority
 --      and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 			and orderdate >= convert(datetime, @c_date_start)
 			and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
       set @n_sum_export = @n_export1 + @n_export2
       select @c_type_descr = description
       from codelkup (nolock)
       where code = @c_type
       and listname = 'OrderType'
       insert into #result
       values(@c_type_descr,@c_company,@n_sum_ordline_no,@n_sum_ord_no,@n_sum_willcall,@n_sum_norm,@n_sum_critical,@n_sum_export)
       select @n_willcall1 = 0,
              @n_willcall2 = 0,
              @n_norm1 = 0,
              @n_norm2 = 0,
              @n_critical1 = 0,
              @n_critical2 = 0,
              @n_export1 = 0,
              @n_export2 = 0,
              @n_sum_ordline_no = 0,
              @n_sum_ord_no = 0,
              @n_sum_willcall = 0,
              @n_sum_norm = 0,
              @n_sum_critical = 0,
              @n_sum_export = 0
       fetch next from cur1 into @c_type
    end
 close cur1
 deallocate cur1
 -- for footer
 select @n_success=count(*)
 from orders a (nolock),
 mbol b (nolock)
 where a.mbolkey = b.mbolkey
 and a.storerkey = @c_storerkey
 and b.status = '9'
 and convert(char(10),a.deliverydate) >= convert(char(10),b.departuredate)
 -- and a.orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 and a.orderdate >= convert(datetime, @c_date_start)
 and a.orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
 select @n_failure=count(*)
 from orders a (nolock),
 mbol b (nolock)
 where a.mbolkey = b.mbolkey
 and a.storerkey = @c_storerkey
 and b.status = '9'
 and convert(char(10),a.deliverydate) < convert(char(10),b.departuredate)
 -- and a.orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 and a.orderdate >= convert(datetime, @c_date_start)
 and a.orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
 select @n_due_orders=count(*)
 from orders (nolock)
 where storerkey = @c_storerkey
 and mbolkey = ''
 -- and orderdate between convert(datetime,@c_date_start) and convert(datetime,@c_date_end)
 and orderdate >= convert(datetime, @c_date_start)
 and orderdate < dateadd(day, 1, convert(datetime, @c_date_end))
 select 
 Suser_Sname(),
 start_date=convert(datetime,@c_date_start), 
 end_date=convert(datetime,@c_date_end),
 *,
 success_qty=@n_success,
 failure_qty=@n_failure,
 due_qty=@n_due_orders
 from #result
 drop table #result
 end -- end of procedure

GO