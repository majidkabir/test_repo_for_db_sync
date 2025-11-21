SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nsp_replenish_warehouse                            */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 2019-03-29   TLTING01  1.1 Bug fix                                   */  
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_replenish_warehouse]  
@c_facility NVARCHAR(5),  
@c_zone  NVARCHAR(10)  
as  
begin -- main  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   declare @c_loc NVARCHAR(10),  
   @c_storerkey NVARCHAR(18),  
   @c_sku NVARCHAR(20),  
   @c_descr NVARCHAR(60),  
   @c_packkey NVARCHAR(10),  
   @c_loctype NVARCHAR(10),  
   @n_qtyneeded int,  
   @c_fromfacility NVARCHAR(5),  
   @c_fromloc NVARCHAR(10),  
   @c_fromid NVARCHAR(18),  
   @n_qty int,  
   @n_fromqty int,  
   @n_shelflife int,  
   @d_lottable04 datetime,  
   @n_maxpallet int,  
   @n_pallet_needed int  
   -- create temp table that will hold records needed to be replenish  
   select  lotxlocxid.storerkey,  
   lotxlocxid.sku,  
   sku.descr,  
   sku.packkey,  
   lotxlocxid.loc,  
   LOC.locationtype,  
   qtyneeded = (loc.maxpallet*pack.pallet) - sum(lotxlocxid.qty-lotxlocxid.qtypicked),  
   loc.maxpallet,  
   weeknum = datepart(week, lotattribute.lottable04)  
   into #replenish  
   from lotxlocxid (nolock),  
   lotattribute (nolock),  
   sku (nolock),  
   loc (nolock),  
   pack (nolock)  
   where lotxlocxid.lot = lotattribute.lot  
   and lotxlocxid.storerkey = sku.storerkey  
   and lotxlocxid.sku = sku.sku  
   and lotxlocxid.loc = loc.loc  
   and sku.packkey = pack.packkey  
   and (loc.locationtype = 'DRIVEIN' or loc.locationtype = 'SELECTIVE')  
   and loc.locationcategory <> 'OVERFLOW'  
   and loc.facility = @c_facility  
   and loc.putawayzone = @c_zone  
   group by lotxlocxid.storerkey,  
   lotxlocxid.sku,  
   sku.packkey,  
   sku.descr,  
   lotxlocxid.loc,  
   LOC.locationtype,  
   loc.maxpallet,  
   pack.pallet,  
   lotattribute.lottable04  
   having sum(lotxlocxid.qty-lotxlocxid.qtypicked) < (loc.maxpallet*pack.pallet)  
   and sum(lotxlocxid.qty-lotxlocxid.qtypicked) > 0  
   -- create temp table that will hold the result set  
   select fromfacility = space(5),  
   facility = @c_facility,  
   putawayzone = @c_zone,  
   locationtype,  
   fromloc = space(10),  
   loc,  
   storerkey,  
   sku,  
   descr,  
   id = space(18),  
   lottable04 = '00/00/00',  
   palletqty = 0,  
   caseqty = 0,  
   eachesqty = 0,  
   totalqty = 0  
   into #result  
   from #replenish  
   where 1 = 2  
   select @c_loc = ''  
   while (2=2)  
   begin -- (2=2)  
      set rowcount 1  
      select @c_storerkey = storerkey,  
      @c_sku =  sku,  
      @c_descr = descr,  
      @c_packkey = packkey,  
      @c_loc = loc,  
      @c_loctype = locationtype,  
      @n_qtyneeded = qtyneeded,  
      @n_maxpallet = maxpallet  
      from #replenish  
      where loc > @c_loc  
      order by loc  
  
      if @@rowcount = 0 break  
      set rowcount 0  
      select @n_shelflife = isnull(shelflife, 0)  
      from sku (nolock)  
      where storerkey = @c_storerkey  
      and sku =@c_sku  
      select @n_pallet_needed = @n_maxpallet - count(distinct id)  
      from lotxlocxid (nolock)  
      where loc = @c_loc  
      and qty > 0  
      if @n_pallet_needed > 0 -- location needs @n_pallet_needed of IDs  
      begin  
         set rowcount @n_pallet_needed  
  
         -- select number of IDs needed (@n_pallet_needed) to fulfill maxpallet  
         insert #result  
         select UPPER(facility), UPPER(@c_facility), @c_zone, UPPER(@c_loctype), UPPER(lotxlocxid.loc), UPPER(@c_loc),  
         @c_storerkey, @c_sku, @c_descr, id, lottable04, 0, 0, 0, qty=sum(qty-qtypicked)  
         from lotxlocxid (nolock) join loc (nolock)  
         on lotxlocxid.loc = loc.loc  
         join #replenish (nolock)  
         on lotxlocxid.storerkey = #replenish.storerkey  
         and lotxlocxid.sku = #replenish.sku  
         join lotattribute (nolock)  
         on lotxlocxid.lot = lotattribute.lot  
         where facility <> @c_facility  
         and lotxlocxid.storerkey = @c_storerkey  
         and lotxlocxid.sku = @c_sku  
         and #replenish.weeknum = case lottable04  
         when null then 0  
      else datepart(week, lottable04)  
      end  
      and locationflag = 'NONE'  
      and id not in (select id from #result)  
      group by facility, lotxlocxid.loc, id, hostwhcode, lottable04  
      having sum(qty-qtypicked) > 0  
      order by dateadd(day, @n_shelflife, lottable04), sum(qty-qtypicked) desc  
  
      set rowcount 0  
   end  
end -- (2=2)  
set rowcount 0  
  
-- update result set with correct palletcnt, casecnt and each conversion  
update #result  
set caseqty = case  
when casecnt > 0 then floor(totalqty/casecnt)  
else 0  
end  
from sku (nolock) join #result  
on sku.storerkey = #result.storerkey  
and sku.sku = #result.sku  
join pack (nolock)  
on sku.packkey = pack.packkey  
--  update #result  
--  set palletqty = case  
--           when pallet > 0 then floor(totalqty/pallet)  
--           else 0  
--          end,  
--    caseqty = case  
--          when casecnt > 0 then (floor(totalqty/casecnt)) - ((floor(totalqty/pallet)*pallet))/casecnt  
--          else 0  
--         end  
--  from sku (nolock) join #result  
--   on sku.storerkey = #result.storerkey  
--    and sku.sku = #result.sku  
--  join pack (nolock)  
--   on sku.packkey = pack.packkey  
--  
--  update #result  
--  set eachesqty = totalqty - (palletqty*pallet) - (caseqty*casecnt)  
--  from sku (nolock) join #result  
--   on sku.storerkey = #result.storerkey  
--    and sku.sku = #result.sku  
--  join pack (nolock)  
--   on sku.packkey = pack.packkey  
  
select * from #result order by loc, fromloc, id -- return result set  
drop table #result  
drop table #replenish  
end -- main  

GO