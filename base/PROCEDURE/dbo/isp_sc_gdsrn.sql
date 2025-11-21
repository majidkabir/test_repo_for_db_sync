SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_sc_gdsrn]
as
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
declare @c_externreceiptkey NVARCHAR(20),
        @c_pokey NVARCHAR(18),
        @c_sku NVARCHAR(20),
        @n_qty int,
        @c_toloc NVARCHAR(10)

create table #result(
   externreceiptkey NVARCHAR(20),
   pokey NVARCHAR(18) ,
   sku NVARCHAR(20),
   goodqty int null,
   badqty int null,
   toloc NVARCHAR(10)
)

select @c_externreceiptkey = '',
       @c_pokey = '',
       @c_sku = '',
       @c_toloc = '',
       @n_qty = 0

declare cur1 cursor FAST_FORWARD READ_ONLY 
for
select a.externreceiptkey, a.pokey, b.sku, b.qtyreceived, b.toloc from receipt a (nolock), receiptdetail b (nolock)
where a.receiptkey = b.receiptkey
and b.toloc not in ('damage','hdamage')
and a.externreceiptkey='008816'
and a.rectype = 'RGR'
union
select a.externreceiptkey, a.pokey, b.sku, b.qtyreceived, b.toloc from receipt a (nolock), receiptdetail b (nolock)
where a.receiptkey = b.receiptkey
and b.toloc in ('damage','hdamage')
and a.externreceiptkey='008816'
and a.rectype = 'RGR'

open cur1

fetch next from cur1 into @c_externreceiptkey, @c_pokey, @c_sku, @n_qty, @c_toloc

while(@@fetch_status=0)
   begin
       
      if (@c_toloc<>'damage' or @c_toloc<>'hdamage')
         begin
            insert into #result(externreceiptkey, pokey, sku, goodqty, toloc)
            values(@c_externreceiptkey, @c_pokey, @c_sku, @n_qty, @c_toloc)
         end
      else
         begin
            insert into #result(externreceiptkey, pokey, sku, badqty, toloc)
            values(@c_externreceiptkey, @c_pokey, @c_sku, @n_qty, @c_toloc)
         end

      fetch next from cur1 into @c_externreceiptkey, @c_pokey, @c_sku, @n_qty, @c_toloc
   end

close cur1
deallocate cur1

select externreceiptkey, pokey, sku, goodqty=sum(goodqty), badqty=sum(badqty) from #result
group by externreceiptkey, pokey, sku

drop table #result

end


GO