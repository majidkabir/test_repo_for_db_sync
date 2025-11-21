SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[isp_nikecn_export_receipt](
	@c_headerprefix NVARCHAR(1),
	@c_detailprefix NVARCHAR(1),
	@c_recflag NVARCHAR(1),
	@c_refcode NVARCHAR(1),
	@c_tranid NVARCHAR(15)
)
as
-- insert candidate records into table nikecn_receipt on dtsitf db
begin
	declare @c_key NVARCHAR(10),
   @c_glacct NVARCHAR(40)

	select @c_key = ''
	while(1=1)
	begin
		select @c_key = min(key1)
		from transmitlog (nolock)
		where transmitflag = '1'
			and tablename = 'NIKERCV'
			and key1 > @c_key

		if @@rowcount = 0 or @c_key is null
			break

		-- insert receipt header
		if not exists (select 1 from dtsitf..nikecn_receipt (nolock) 
			       where receiptkey = @c_key)
		begin
			insert dtsitf..nikecn_receipt (rectype, receiptkey, tranid, recflag, trandate, refnum, crossref, 
					refcode, container, status, pokey, glacct,potype )
				select @c_headerprefix, @c_key, @c_key,
            @c_recflag, convert(char(11),replace(convert(char(11), r.effectivedate, 106), ' ','-')),
					@c_key, r.warehousereference, @c_refcode, 
            r.CarrierReference, '1', r.ExternReceiptkey,
--           CASE  WHEN r.warehousereference iN ('CHN61', 'CHN63', 'CHN70', 'CHN98', 'CHN79') THEN '791-CN00-03-000-00-210-01-5104-NIK-000-000-00-01-000000'
--                   WHEN r.warehousereference IN ('CHN68', 'CHN69', 'CHN78', 'CHN99') THEN '791-CN00-03-000-00-210-01-5104-605-000-000-00-01-000000'
--            END, 
            cl.Long,
            r.termsnote
				from receipt r (nolock) 
            join facility f (nolock) on (r.facility = f.facility)
            left outer join codelkup cl (nolock) on (cl.code = r.warehousereference and cl.listname = 'GLACCT')
				where r.receiptkey = @c_key

			-- insert receipt detail
			insert dtsitf..nikecn_receipt (rectype, receiptkey, tranid, gpc, sku, qty, status, subinvcode)
				select @c_detailprefix, @c_key, @c_key, s.susr4, rd.sku, sum(qtyreceived), '1', rd.Lottable03
				from receiptdetail rd (nolock) join sku s (nolock)
					on rd.storerkey = s.storerkey
						and rd.sku = s.sku
				where rd.receiptkey = @c_key
            group by s.susr4, rd.sku, rd.lottable03
            having sum(qtyreceived) > 0

			-- update poid in header
			update dtsitf..nikecn_receipt
			set poid = lottable02
			from receiptdetail rd join dtsitf..nikecn_receipt r
				on rd.receiptkey = r.receiptkey
			where rd.receiptkey = @c_key
				and lottable02 > ''

		end
	end
end

GO