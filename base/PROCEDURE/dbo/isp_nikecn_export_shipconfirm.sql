SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[isp_nikecn_export_shipconfirm] (
	@c_headerprefix NVARCHAR(1),
	@c_detailprefix NVARCHAR(1),
	@c_openflag NVARCHAR(1),
   @c_storerkey NVARCHAR(15) 
)
AS
-- insert candidate records into table nikecn_ship on dtsitf db
BEGIN
	DECLARE @c_key NVARCHAR(10),
           @c_lines   int,
           @b_success int,
           @cHeaderID NVARCHAR(15),
           @n_err     int, 
           @c_errmsg  NVARCHAR(255), 
           @c_picklineno NVARCHAR(10)

	select @c_key = ''
	while (1=1)
	begin
		select @c_key = min(key1)
		from transmitlog (nolock)
      JOIN ORDERS (NOLOCK) ON (Orders.Orderkey = Transmitlog.Key1
                               AND Orders.Storerkey = @c_storerkey )
		where transmitflag = '1'
			and tablename = 'NIKESHIP'
			and key1 > @c_key

		if @@rowcount = 0 or @c_key is null
			break

		-- insert order header
		if not exists (select 1 
							from dtsitf..nikecn_ship (nolock) 
							where orderkey = @c_key)
		begin
         SELECT @b_success = 0
         EXECUTE   nspg_getkey
         'NIKESHIP'
         , 10
         , @cHeaderID OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT

         SELECT @cHeaderID = dbo.fnc_RTRIM(Convert(char(10), CAST(@cHeaderID as int) ))

			insert dtsitf..nikecn_ship (rectype, headerid, orderkey, pickslip, ordernum, needdate, shipdate, openflag, dnnum, status)
				select @c_headerprefix, @cHeaderID, @c_key, o.externorderkey, o.ordergroup, 
					convert(char(11),replace(convert(char(11), o.deliverydate, 106), ' ','-')),
					convert(char(11),replace(convert(char(11), m.editdate, 106), ' ','-')), @c_openflag, md.loadkey, '1'
				from mbol m (nolock) 
            join mboldetail md (nolock) on (m.mbolkey = md.mbolkey)
				join orders o (nolock) on (md.orderkey = o.orderkey)
				where md.orderkey = @c_key 
            and o.storerkey = @c_storerkey
	
			-- insert order detail
			insert dtsitf..nikecn_ship (rectype, headerid, orderkey, pickslip, pickinglineid, sku, reqqty, shipqty, gpc, status, subinv)
				select @c_detailprefix, @cHeaderID, @c_key, od.externorderkey, od.orderlinenumber, od.sku, originalqty, shippedqty+qtypicked+qtyallocated,
					s.susr4, '1', od.userdefine01
				from orderdetail od (nolock) join sku s (nolock)
					on od.storerkey = s.storerkey
						and od.sku = s.sku
				where od.orderkey = @c_key
            and od.storerkey = @c_storerkey
            and (shippedqty+qtypicked+qtyallocated) > 0 -- SOS 10158: wally 7mar03

         -- Added By SHONG 04-Mar-2003
         UPDATE TransmitLog
         SET Key3 = @c_storerkey
         WHERE Key1 = @c_key
         AND   TableName = 'NIKESHIP'
         -- End
         
         -- SOS 10158: wally 07.mar.03
         -- commented the stmt block below, exception of zero ship is done above in the insert stmt

         --Added Date : 26 Feb 2003
         --Do not export those lines which has ShippedQty = 0
         /*
         Select * into #tempship From dtsitf..nikecn_ship
         Where shipqty = 0
           and orderkey = @c_key
           and rectype = 'L' 
        
         delete from dtsitf..nikecn_ship 
         where orderkey in (select orderkey from #tempship)
           and pickinglineid in (select pickinglineid from #tempship)

         drop table #tempship
         --End Add 
         */

         -- wally: 6mar03
         -- commented the stmt below: no need to use orderdetail
         -- update total lines in header
         update dtsitf..nikecn_ship
         set linesshipped = (select count(*)
                             from dtsitf..nikecn_ship (nolock)
                             where orderkey = @c_key
                                and rectype = @c_detailprefix)
         where orderkey = @c_key
            and rectype = @c_headerprefix

			-- update total lines in header
         /*
			select @c_lines = count(*)
			from orderdetail (nolock)
			where orderkey = @c_key

			update dtsitf..nikecn_ship
			set linesshipped = @c_lines
			where orderkey = @c_key
				and rectype = 'H'
         */
		end
	end
end

GO