SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_reorder_forecast](
   @c_storer_start   NVARCHAR(15),
   @c_storer_end     NVARCHAR(15),
   @c_facility_start NVARCHAR(5),
   @c_facility_end   NVARCHAR(5)
)
as 
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
declare @c_storerkey NVARCHAR(15),
        @c_sku NVARCHAR(20),
        @c_descr NVARCHAR(60),
        @n_reorderpoint float(8),
        @n_qty float(8),
        @n_asn_qty float(8),
        @n_po_qty float(8)


create table #result(
    storerkey    NVARCHAR(15),
    sku          NVARCHAR(20),
    descr        NVARCHAR(60),
    qty          float(8) null,
    qtyonorder   float(8) null,
    reorderpoint float(8) null
)

declare cur1 cursor FAST_FORWARD READ_ONLY for
select a.storerkey, a.sku, b.descr, b.reorderpoint,sum(qty) from
skuxloc a (nolock), sku b (nolock)
where a.sku = b.sku
and a.storerkey = b.storerkey
and b.storerkey between @c_storer_start and @c_storer_end
and b.facility between @c_facility_start and @c_facility_end
group by a.storerkey,a.sku, b.descr, b.reorderpoint
order by a.storerkey, a.sku

open cur1

fetch next from cur1 into @c_storerkey, @c_sku, @c_descr, @n_reorderpoint, @n_qty

while (@@fetch_status=0)
   begin 
      -- get open ASN receiving qty      
      select @n_asn_qty = isnull(b.qtyexpected,0)
      from receipt a (nolock), receiptdetail b (nolock)
      where a.receiptkey = b.receiptkey
      and b.sku = @c_sku
      and b.storerkey = @c_storerkey
      and a.asnstatus = '0'

      -- get outstanding Po qty ( = qtyordered - qtyreceived )
      select @n_po_qty = isnull(b.qtyordered - b.qtyreceived,0)
      from po a (nolock), podetail b (nolock)
      where b.sku = @c_sku
      and a.pokey = b.pokey
      and b.storerkey = @c_storerkey
      and b.qtyordered <> b.qtyreceived
      and a.status = '0'

      insert into #result
      values(@c_storerkey, @c_sku, @c_descr, @n_qty, isnull(@n_asn_qty,0)+isnull(@n_po_qty,0), isnull(@n_reorderpoint,0))  

      fetch next from cur1 into @c_storerkey, @c_sku, @c_descr, @n_reorderpoint, @n_qty
   end

close cur1
deallocate cur1

select * from #result

drop table #result

end







GO