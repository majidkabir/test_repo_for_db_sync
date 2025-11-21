SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[isp_nikecn_export_return](
	@c_headerprefix NVARCHAR(1),
	@c_detailprefix NVARCHAR(1),
	@c_grade NVARCHAR(1)
)
as
-- insert candidate records into table nikecn_return on dtsitf db
begin
	declare @c_key NVARCHAR(10),
	@n_lines int,
        @c_userdefine07 NVARCHAR(30),
        @c_facility NVARCHAR(5),
        @c_subinvcode NVARCHAR(30),
        @c_subinvcodefac NVARCHAR(30)
 
	select @c_key = ''
	while(1=1)
	begin  
		select @c_key = min(key1)
		from transmitlog (nolock)
		where transmitflag = '1'
			and tablename = 'NIKERET'
			and key1 > @c_key

		if @@rowcount = 0 or @c_key is null
			break
                  
                SELECT @c_facility = facility, 
                       @c_grade = Processtype
                FROM Receipt (nolock)
                Where receiptkey = @c_key
-- 
--                 SELECT @c_subinvcodefac = Codelkup.Short
--                 FROM Codelkup (nolock)
--                 WHERE Codelkup.Code = @c_facility
--                  AND  Codelkup.Listname = 'Facility'

               IF (@c_facility = 'NSH01') Or (@c_facility = 'NSH02')
                 Begin
                    Select @c_subinvcode = 'SHA DC'
                 End
               Else if (@c_facility = 'NGZ01') Or (@c_facility = 'NGZ02')
                 Begin
                    Select @c_subinvcode = 'GZ DC'
                 End
               Else if (@c_facility = 'NSH03') Or (@c_facility = 'NGZ03')
                 Begin
                    Select @c_subinvcode = 'SMI'
                 End
    
     
		-- insert receipt header
		if not exists (select 1 from dtsitf..nikecn_return (nolock) 
                               where receiptkey = @c_key)
		begin 
			insert dtsitf..nikecn_return (rectype, receiptkey, subinvcode, customernum, requestdate, returndate, inspectdate, authorisenum, type, ctn, carrier, status)
				select @c_headerprefix, @c_key, @c_subinvcode, r.warehousereference, convert(char(10),r.effectivedate,20), convert(char(10), r.editdate, 20),convert(char(10),r.vehicledate,20), r.externreceiptkey,
				       r.processtype, r.containerqty, r.carrierkey, '1'
				from receipt r (nolock)
				where r.receiptkey = @c_key

			-- insert receipt detail
			insert dtsitf..nikecn_return (rectype, receiptkey, lineid, gpc, sku, grade, qty, poid, factorycode,defectivetype, defectivecode, status)
				select @c_detailprefix, @c_key, rd.Receiptlinenumber,s.susr4, rd.sku, @c_grade, rd.qtyexpected, rd.lottable02, VoyageKey,
					rd.Vesselkey,rd.subreasoncode, '1'
				from receiptdetail rd (nolock) join sku s (nolock)
					on rd.storerkey = s.storerkey
						and rd.sku = s.sku
				where rd.receiptkey = @c_key

			-- update totallines in header
			select @n_lines = count(*)
			from receiptdetail (nolock)
			where receiptkey = @c_key

			update dtsitf..nikecn_return
			set totallines = @n_lines
			where receiptkey = @c_key
				and rectype = @c_headerprefix
		end
	end
end

GO