SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_IntegrityChk                                           */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/***************************************************************************/    
CREATE PROC [dbo].[isp_IntegrityChk] (@c_ArchiveDBName NVARCHAR(20))
As 
Begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE @cExecStatements NVARCHAR(max)
	SET NOCOUNT ON

	print '***********************************************************'
	print ' '
   select 'Script ' = 'isp_IntegrityChk ', 'Database ' = convert(char(15), db_name()), 'Current date' = convert(char(25), getdate(), 113)
	print '***********************************************************'
	print ' '

	select '<1> BackEndShip Problem '
	print '   => OrderDetail is Missing while Pickdetail Not yet Shipped'
	print '   => pls notify RT'
	select distinct pd.orderkey 
	from  pickdetail pd (nolock)
	join  orderdetail od (nolock) on pd.orderkey = od.orderkey and pd.orderlinenumber = od.orderlinenumber
	where od.orderlinenumber is null
	and   pd.shipflag = 'Y'
	and   pd.status < '9'
	
	
	select '<2> BackEnd Ship Problem '
	print  '   => Ship Constraints for Overallocation when LocType <> PickFace'
	print  '   => Pls rectify the SKUXLOC.locationtype setting'
	select c.locationtype, b.storerkey, b.sku, b.loc, 
			 qtyexpect = sum(b.qtyexpected)
			 --, lll_qty = sum(b.qty), pd_qty = sum(a.qty) 
	from  pickdetail a (nolock), lotxlocxid b (nolock), skuxloc c (nolock)
	where a.lot = b.lot 
	and   a.loc = b.loc
	and   a.sku = b.sku
	and 	b.storerkey = c.storerkey
	and   b.sku = c.sku
	and   b.loc = c.loc
	and   c.locationtype not in ('PICK', 'CASE')
	and   b.qtyexpected > 0
	and   a.status < '9'
	group by c.locationtype, b.storerkey, b.sku, b.loc
	

	select '<3> Pick Confirm VARIANCE (ScanOut) - Pickdetail status < "5"'
	print  '   => Pls re-scan out the pickslip'
	select DISTINCT a.pickslipno --, d.orderkey, c.loadkey, d.sku, d.loc, d.lot, d.qty
	from pickinginfo a (nolock)
	join pickheader b (nolock) on a.pickslipno = b.pickheaderkey and zone = '3'
	join orderdetail c (nolock)on c.orderkey = b.orderkey 
	join pickdetail d (nolock) on d.orderkey = c.orderkey and d.orderlinenumber = c.orderlinenumber
	where a.scanoutdate is not null
	and   d.status < '5'
	union	
	select DISTINCT a.pickslipno --, d.orderkey, c.loadkey, d.sku, d.loc, d.lot, d.qty
	from pickinginfo a (nolock)
	join pickheader b (nolock) on a.pickslipno = b.pickheaderkey and zone in ('7', '8', '9') 
	join orderdetail c (nolock) on c.loadkey = b.externorderkey 
	join pickdetail d (nolock) on d.orderkey = c.orderkey and d.orderlinenumber = c.orderlinenumber
	where a.scanoutdate is not null
	and   d.status < '5'
	and   b.externorderkey <> ''
	and   b.orderkey = ''
	union	
	select DISTINCT a.pickslipno --, d.orderkey, c.loadkey, d.sku, d.loc, d.lot, d.qty
	from pickinginfo a (nolock)
	join pickheader b (nolock) on a.pickslipno = b.pickheaderkey and zone in ('7', '8', '9') 
	join orderdetail c (nolock) on c.loadkey = b.externorderkey and c.orderkey = b.orderkey
	join pickdetail d (nolock) on d.orderkey = c.orderkey and d.orderlinenumber = c.orderlinenumber
	where a.scanoutdate is not null
	and   d.status < '5'
	and   b.externorderkey <> ''
	and   b.orderkey <> ''
	union
	-- for wave
	select DISTINCT a.pickslipno --, d.orderkey, wavekey = c.userdefine09, d.sku, d.loc, d.lot, d.qty
	from pickinginfo a (nolock)
	join pickheader b (nolock) on a.pickslipno = b.pickheaderkey and zone in ('7', '8', '9') 
	join orders c (nolock) on c.userdefine09 = b.wavekey and c.orderkey = b.orderkey
	join pickdetail d (nolock) on d.orderkey = c.orderkey 
	where a.scanoutdate is not null
	and   d.status < '5'
	and   b.wavekey <> ''
	and   c.userdefine09 <> ''
	union 
	select DISTINCT a.pickslipno --, d.orderkey, d.loadkey, e.sku, e.loc, e.lot, e.qty
	from pickinginfo a (nolock)
	join pickheader b (nolock)  on a.pickslipno = b.pickheaderkey and zone = 'XD'
	join refkeylookup c (nolock) on c.pickslipno = a.pickslipno
	join orderdetail d (nolock) on d.orderkey = c.orderkey and d.orderlinenumber = c.orderlinenumber
	join pickdetail e (nolock) on e.orderkey = d.orderkey and e.orderlinenumber = d.orderlinenumber
	where a.scanoutdate is not null
	and   e.status < '5'
	order by a.pickslipno
	
	
	select '<4> Pick Confirm Problem (OrderDetail) '
	print  '   => Zero QtyPicked while OD.Status is "5"'                                                                
	print  '   => Pls re-scan out, contact RT if problem persists after re-scanout'
	select od.storerkey, od.orderkey, od.sku, 
			 -- openqty = sum(od.openqty), qtyalloc = sum(od.qtyallocated), 
			 qtypick = sum(od.qtypicked),
			 -- qtyship = sum(od.shippedqty), 
			 od.status 
	from  orderdetail od (nolock)
	where od.status = '5'
	group by od.storerkey, od.orderkey, od.sku, od.status
	having sum(od.qtypicked) = 0 and sum(qtyallocated) > 0

	
	select '<5> Ship VARIANCE (Mark Ship) '
	print  '   => Pickdetail status < "9" but record in ITRN'
	print  '   => Pls contact RT'
	select pd.pickdetailkey, pd.orderkey, pd.sku, pd.qty, pd.status 
	from  pickdetail pd (nolock)
	left  outer join itrn i (nolock) on pd.pickdetailkey = i.sourcekey
	where pd.status = '5' and i.sourcekey is not null
	and   i.sourcetype = 'ntrPickDetailUpdate'
	
	
	select '<6> Ship VARIANCE (Mark Ship) '
	print  '    => Pickdetail Status "9" but record not in ITRN'	
	print  '    => Pls contact RT'
	select p.pickdetailkey, p.orderkey, p.storerkey, p.sku, p.loc, p.lot, p.id, p.qty
	into  #temppd 
	from  pickdetail p (nolock)
	left  outer join itrn i (nolock) on p.pickdetailkey = i.sourcekey
	where p.status = '9'
	and   i.sourcekey is null
	and   i.sourcetype = 'ntrPickDetailUpdate'
	and   p.qty > 0
	
-- 	select p.pickdetailkey, p.orderkey, p.storerkey, p.sku, -- p.loc, p.lot, p.id, 
-- 			 p.qty
-- 	from  #temppd p (nolock)
-- 	left  outer join ARCHIVE..itrn i (nolock) on p.pickdetailkey = i.sourcekey
-- 	where i.sourcekey is null
	
	SELECT @cExecStatements = ''
	SELECT @cExecStatements  = N'	select p.pickdetailkey, p.orderkey, p.storerkey, p.sku, p.qty '
									   + ' from #temppd p ' 
										+ ' left outer join ' + dbo.fnc_RTrim(@c_ArchiveDBName) +  '.dbo.itrn i (NOLOCK) on p.pickdetailkey = i.sourcekey '
										+ ' where i.sourcekey is null ' 
	EXEC (@cExecStatements)

	drop table #temppd
	
	
	select '<7> Ship Problem (OrderDetail) '
	print  '   => Zero OD.ShippedQty but Pickdetail already shipped'
	select od.storerkey, od.orderkey, od.sku, od_status = od.status, pd_status = min(pd.status) 
			 -- ,qtypick = sum(od.qtyallocated+od.qtypicked), qtyship = sum(od.shippedqty)
			 -- , pdqty = sum(pd.qty)
	from  orderdetail od (nolock)
	left  outer join pickdetail pd (nolock) on pd.orderkey = od.orderkey and pd.orderlinenumber = od.orderlinenumber
	where od.status = '9'
	and   od.qtypicked + od.qtyallocated > 0
	group by od.storerkey, od.orderkey, od.sku, od.status
	having min(pd.status) = '9'
	
			
	select '<8> POD Problem (Mark Ship) '
	print  '   =>- Missing POD for Shipped MBOL'	
	select b.mbolkey, b.mbollinenumber, b.orderkey, b.loadkey
	into  #temppod
	from  mbol a (nolock)
	inner join mboldetail b (nolock) on a.mbolkey = b.mbolkey
	left  outer join pod c (nolock) on b.mbolkey = c.mbolkey and  b.Mbollinenumber = c.Mbollinenumber
	inner join orders d (nolock) on b.orderkey = d.orderkey 
	inner join facility e (nolock) on e.facility = d.facility and (
		e.userdefine01 = 'POD' OR e.userdefine02 = 'POD' OR e.userdefine03 = 'POD' OR e.userdefine04 = 'POD' OR e.userdefine05 = 'POD' OR 
		e.userdefine06 = 'POD' OR e.userdefine07 = 'POD' OR e.userdefine08 = 'POD' OR e.userdefine09 = 'POD' OR e.userdefine10 = 'POD' OR 
		e.userdefine11 = 'POD' OR e.userdefine12 = 'POD' OR e.userdefine13 = 'POD' OR e.userdefine14 = 'POD' OR e.userdefine15 = 'POD' OR 
		e.userdefine16 = 'POD' OR e.userdefine17 = 'POD' OR e.userdefine18 = 'POD' OR e.userdefine19 = 'POD' OR e.userdefine20 = 'POD' )
	where a.status = '9'
	and   c.mbollinenumber is null

	
-- 	select a.mbolkey, a.mbollinenumber, a.orderkey, a.loadkey
-- 	from  #temppod a (nolock)
-- 	left  outer join ARCHIVE..pod b (nolock) on a.mbolkey = b.mbolkey and  a.Mbollinenumber = b.Mbollinenumber
-- 	where b.mbollinenumber is null
-- 	order by a.mbolkey

	SELECT @cExecStatements = ''
	SELECT @cExecStatements  = N'	select a.mbolkey, a.mbollinenumber, a.orderkey, a.loadkey '
									   + ' from  #temppod a (nolock) ' 
										+ ' left outer join ' + dbo.fnc_RTrim(@c_ArchiveDBName) +  '..pod b (nolock) on a.mbolkey = b.mbolkey and  a.Mbollinenumber = b.Mbollinenumber '
										+ ' where b.mbollinenumber is null ' 
										+ ' order by a.mbolkey '
	EXEC (@cExecStatements)
	
	drop table #temppod           
	

	select '<9> TBL UCC Replen Problem (UCC Replen) '	
	print  '    => UCC status not Picked'
	select u.orderkey, -- u.orderlinenumber, 
			 u.sku, u.uccno, 
			 od_stat = od.status, 
			 -- pd_stat = pd.status, 
			 ucc_stat = u.status 
-- 		, uccqty = u.qty, qtyalloc = od.qtyallocated, qtypick = od.qtypicked, replenqty = r.qty 
-- 		, r.fromloc, u.loc 
--			, confirmed, r.ReplenishmentGroup
	from  replenishment r (nolock), ucc u (nolock), orderdetail od (nolock), pickdetail pd (nolock)
	where r.refno = u.uccno
	and   u.orderkey = od.orderkey
	and  	u.orderlinenumber = od.orderlinenumber
	and   od.orderkey = pd.orderkey
	and   od.orderlinenumber = pd.orderlinenumber 
	and   u.pickdetailkey = pd.pickdetailkey
	and   r.confirmed = 'Y'
	and   od.qtypicked > 0
	and   od.status = '5'
	and   pd.status = '5'
	and   u.status < '5'
	
	
	select '<10> TBL UCC Replen Problem (UCC Replen / Wave Allocation)'
	print  '    => Replenish Double carton'
	-- Run this Script 2 check Replen double carton after Wave Allocation
	declare @c_storerkey NVARCHAR(10), @c_wavekey NVARCHAR(10)
	select @c_storerkey = '11306'
	select @c_wavekey = ''
	
	select od.sku, od.lottable02, openqty = sum(od.openqty), 
			   qtyalloc = sum(od.qtyallocated), isnull(r.replenqty, 0) as replenqty, 
			   -- isnull(r.noofcs, 0) as noofcs, 
	  	    case when isnull(r.noofcs, 0) > 0 
	  				then max(isnull(r.replenqty, 0) / isnull(r.noofcs, 0)) 
	  				else max(isnull(r.replenqty, 0)) 
	 				end as casecnt
	from  orders o (nolock)
	inner join orderdetail od (nolock) on o.orderkey = od.orderkey
	left outer join (
						  select rl.replenno, rl.storerkey, rl.sku, sum(rl.qty) as replenqty, count(rl.refno) as noofcs
					     from replenishment rl (nolock)
						  join loc (nolock) on rl.toloc = loc.loc
					     where 1 = 1
						  -- and   rl.replenno = @c_wavekey
						  and   loc.locationtype IN ('CASE', 'PICK')
						  group by rl.replenno, rl.storerkey, rl.sku) as r 
								on o.userdefine09 = r.replenno and od.sku = r.sku and od.storerkey = r.storerkey				
	where o.storerkey = @c_storerkey
	-- and  o.userdefine09 = @c_wavekey
	and      od.qtyallocated > 0 
	and      r.replenqty > 0
	group by od.sku, r.replenqty, r.noofcs, od.lottable02
	having isnull(r.noofcs, 0) > 
				case when isnull(r.noofcs, 0) > 0 
						and (sum(od.qtyallocated) % max(isnull(r.replenqty, 0) / isnull(r.noofcs, 0))) = 0
							 then sum(od.qtyallocated) / max(isnull(r.replenqty, 0) / isnull(r.noofcs, 0))  
					  	when isnull(r.noofcs, 0) > 0 and (sum(od.qtyallocated) % max(isnull(r.replenqty, 0) / isnull(r.noofcs, 0))) <>  0
							  then (sum(od.qtyallocated) /  max(isnull(r.replenqty, 0) / isnull(r.noofcs, 0))) + 1
				end
	order by od.sku, od.lottable02 desc			
	

	Print '<11> Pack Confirm VARIANCE (Packing Finalize) - Total Pick Qty <> Total Confirm Pack Qty '
	select ph.orderkey, pickqty = max(p.qty), packqty = sum(pd.qty)
	from packheader ph (nolock)
	join packdetail pd (nolock) on ph.pickslipno = pd.pickslipno
	join (select p.orderkey, qty = sum(p.qty)
		   from pickdetail p  (nolock) 
			group by p.orderkey) as p on ph.orderkey = p.orderkey
	where ph.orderkey is not null and ph.orderkey <> ''
	-- and   ph.status = '9'
	group by ph.orderkey
	having sum(pd.qty) <> max(p.qty)


	Print '<12> Pack Confirm VARIANCE (Packing Finalize) - Total Pick Qty <> Total Confirm Pack Qty (Conso P/S)'
	select ph.loadkey, pickqty = max(p.qty), packqty = sum(pd.qty)
	from packheader ph (nolock)
	join packdetail pd (nolock) on ph.pickslipno = pd.pickslipno
	join (select o.loadkey, qty = sum(p.qty)
		   from pickdetail p  (nolock) 
			join orders o (nolock) on p.orderkey = o.orderkey
			group by o.loadkey) as p on p.loadkey = ph.loadkey
	where ph.loadkey is not null and ph.loadkey <> ''
	and   ph.orderkey = ''
	-- and   ph.status = '9'
	group by ph.loadkey
	having sum(pd.qty) <> max(p.qty)


	print ' '
	print '<<< End Of Checking >>>'

	SET NOCOUNT OFF

/*

select sum(qty) from pickdetail (nolock) where orderkey = '0010292705'                     
select ph.pickslipno, ph.loadkey, ph.orderrefno, ph.orderkey, qty = sum(pd.qty) from packheader ph (nolock)
join packdetail pd (nolock) on ph.pickslipno = pd.pickslipno
where ph.orderkey = '0010292705'
group by ph.pickslipno, ph.orderrefno, ph.orderkey, ph.loadkey



select sum(qty) from pickdetail (nolock) where orderkey in (select orderkey from orders (nolock) 
where loadkey = '0010129629')                     
select ph.pickslipno, ph.loadkey, ph.orderrefno, ph.orderkey, qty = sum(pd.qty) from packheader ph (nolock)
join packdetail pd (nolock) on ph.pickslipno = pd.pickslipno
where ph.loadkey = '0010129629'
group by ph.pickslipno, ph.orderrefno, ph.orderkey, ph.loadkey


-- <9>
select status, qty, orderkey, orderlinenumber, * from ucc (nolock) where uccno =  '00069302350315127889'
select qty, confirmed, * from replenishment (nolock) where  refno =  '00069302350315127889'
select status, sku, orderkey, orderlinenumber, sum(qty) from pickdetail (nolock) where orderkey = '0006422559' and orderlinenumber = '00089'
group by status, sku, orderkey, orderlinenumber 
                                         
*/                           
                           
End

GO