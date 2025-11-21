SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */

CREATE proc [dbo].[isp_order_n_up_format](
   @c_loadkey NVARCHAR(10),
   @c_allocated NVARCHAR(1)
)
as
begin
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
declare @c_cur_descr NVARCHAR(250),
        @c_pre_descr NVARCHAR(250),
	@c_orderkey NVARCHAR(10),
        @c_externorderkey NVARCHAR(50),  --tlting_ext
	@c_key NVARCHAR(30),
        @n_loopcnt int,
        @n_linenum int,
        @n_rowcount int

set @n_loopcnt = 1
set @n_linenum = 0

create table #result(
   descr NVARCHAR(250),
   linenum int,
   orderkey1 NVARCHAR(10) null,
   orderkey2 NVARCHAR(10) null,
   orderkey3 NVARCHAR(10) null,
   orderkey4 NVARCHAR(10) null,
   orderkey5 NVARCHAR(10) null,
   orderkey6 NVARCHAR(10) null,
)

declare cur1 cursor FAST_FORWARD READ_ONLY
for
select b.description, a.externorderkey, a.orderkey
from orders a (nolock), codelkup b (nolock)
where a.type = b.code
and b.listname = 'ORDERTYPE'
and a.loadkey=@c_loadkey
and a.UserDefine08 = @c_allocated
order by b.description,
	 a.externorderkey

open cur1

fetch next from cur1 into @c_cur_descr, @c_externorderkey, @c_orderkey

set @c_pre_descr = @c_cur_descr

while (@@fetch_status=0)
  begin

     if (@c_pre_descr <> @c_cur_descr) 
        begin
           set @n_loopcnt = 1
        end

     if (@c_externorderkey is null or @c_externorderkey = "")
        begin
	   set @c_key = @c_orderkey
	end
     else
	begin
	   set @c_key = @c_externorderkey
        end     

	
     if (@n_loopcnt % 6)=1
        begin
	   set @n_linenum = @n_linenum + 1
	   
           insert into #result(descr, linenum, orderkey1) 
       	   values(@c_cur_descr, @n_linenum, @c_key)
        end
     else if (@n_loopcnt % 6)=2
        update #result
        set orderkey2 = @c_key
        where descr = @c_cur_descr
        and linenum = @n_linenum
     else if (@n_loopcnt % 6)=3
        update #result
        set orderkey3 = @c_key
        where descr = @c_cur_descr
        and linenum = @n_linenum
     else if (@n_loopcnt % 6)=4
        update #result
        set orderkey4 = @c_key
        where descr = @c_cur_descr
        and linenum = @n_linenum
     else if (@n_loopcnt % 6)=5
        update #result
        set orderkey5 = @c_key
        where descr = @c_cur_descr
        and linenum = @n_linenum
     else if (@n_loopcnt % 6)=0
        update #result
        set orderkey6 = @c_key
        where descr = @c_cur_descr
        and linenum = @n_linenum
     
     set @c_pre_descr = @c_cur_descr

     fetch next from cur1 into @c_cur_descr, @c_externorderkey, @c_orderkey
     
     set @n_loopcnt = @n_loopcnt + 1
  end

close cur1
deallocate cur1


select * from #result

drop table #result

end


GO