SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--nsp_adidasReplen 'adidas', '20110329', '20110331', '1'    
    
CREATE PROC [dbo].[nsp_adidasReplen] (    
   @cstorerkey nvarchar( 15),    
   @ddeliveryfrom datetime,     
   @ddeliveryto datetime,     
   @cSKUGroup nchar(1)    
)      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_DEFAULTS OFF        
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   -- Order demand    
   select od.storerkey, od.sku, sku.busr6, count( distinct o.orderkey) NoOfOrder, sum( od.originalqty) OrderQTY,     
      space( 10) ToLoc,     
      0 VPAvail,     
      0 PFAvail,     
      0 BulkAvail,     
      0 QTYtoReplen    
   into #Demand    
   from orders o (nolock)     
      inner join orderdetail od (nolock) on (o.orderkey = od.orderkey)    
      inner join sku (nolock) on (sku.storerkey = od.storerkey and sku.sku = od.sku)    
   where o.storerkey = @cstorerkey    
      and o.status = '0'    
      and o.deliverydate between @ddeliveryfrom and @ddeliveryto    
      and sku.skugroup = @cSKUGroup    
   group by od.storerkey, od.sku, sku.busr6    
   order by od.storerkey, od.sku, sku.busr6     
    
   -- Update PF loc (mezzanine floor)    
   update #Demand set    
      ToLOC = sl.loc    
   from #Demand d (nolock)    
      inner join     
      (    
         select sl.storerkey, sl.sku, min( sl.loc) loc -- sku could have multi pick face, use min()    
         from skuxloc sl (nolock)     
            inner join loc (nolock) on (sl.loc = loc.loc)    
         where sl.storerkey = @cstorerkey    
            and sl.locationtype in ('case', 'pick')    
            and loc.putawayzone <> 'adidas'    
         group by sl.storerkey, sl.sku    
      ) sl on (d.storerkey = sl.storerkey and d.sku = sl.sku)    
    
   -- Update PF avail    
   update #Demand set    
      PFAvail = sl.PFAvail    
   from #Demand r (nolock)    
      inner join     
      (    
         select sl.storerkey, sl.sku, sum( sl.qty - sl.qtyallocated - sl.qtypicked) PFAvail    
         from skuxloc sl (nolock)    
            inner join loc (nolock) on (sl.loc = loc.loc)    
         where sl.storerkey = @cstorerkey    
            and (sl.locationtype in ('case', 'pick')) -- or loc.loclevel in ( 1, 2))    
            and (sl.qty - sl.qtyallocated - sl.qtypicked) > 0    
            and loc.locationflag not in ('HOLD', 'DAMAGE')    
            and loc.status <> 'HOLD'    
         group by sl.storerkey, sl.sku    
      ) sl on (r.storerkey = sl.storerkey and r.sku = sl.sku)    
    
   -- Update bulk avail    
   update #Demand set    
      BulkAvail = sl.BulkAvail    
   from #Demand r (nolock)    
      inner join     
      (    
         select sl.storerkey, sl.sku, sum( sl.qty - sl.qtyallocated - sl.qtypicked) BulkAvail    
         from skuxloc sl (nolock)    
            inner join loc (nolock) on (sl.loc = loc.loc)    
         where sl.storerkey = @cstorerkey    
            and sl.locationtype not in ('case', 'pick')    
            and (sl.qty - sl.qtyallocated - sl.qtypicked) > 0    
            and loc.locationflag not in ('HOLD', 'DAMAGE')    
            and loc.status <> 'HOLD'    
         group by sl.storerkey, sl.sku    
      ) sl on (r.storerkey = sl.storerkey and r.sku = sl.sku)    
    
   -- update QtytoReplen    
   update #Demand set     
      QTYtoReplen = OrderQTY - VPAvail - PFAvail    
   where (OrderQTY - VPAvail - PFAvail) > 0    
    
   -- delete those don't need replen    
   delete #Demand where QTYtoReplen = 0    
    
    
   -- create blank #replen    
   select StorerKey, SKU, LOC, ID, QTY    
   into #Replen    
   from lotxlocxid (nolock) where 1=0    
    
   declare @cSKU nvarchar( 20)    
   declare @cPrevSKU nvarchar( 20)    
   declare @cFromLOC nvarchar( 10)    
   declare @cFromID nvarchar( 18)    
   declare @cFromLOCID nvarchar( 28)    
   declare @nQTYtoReplen int    
   declare @nQTYAvail int    
    
   declare cur_Demand cursor for     
      select storerkey, sku, qtytoreplen    
      from #Demand    
   open cur_Demand    
   fetch next from cur_Demand into @cStorerKey, @cSKU, @nQTYtoReplen    
   while @@fetch_status = 0    
   begin    
      if @cPrevSKU <> @cSKU    
      begin    
         set @cFromLOCID = ''    
         set @cFromLOC = ''    
         set @cFromID = ''    
         set @cPrevSKU = @cSKU    
      end    
    
      select top 1     
         @cFromLOCID = lli.loc + lli.ID,    
         @cFromLOC = lli.loc,     
         @cFromID = lli.ID,     
         @nQTYAvail = sum( lli.QTY - lli.QTYallocated - lli.QTYpicked)    
      from lotxlocxid lli (nolock)     
         inner join skuxloc sl (nolock) on (lli.storerkey = sl.storerkey and lli.sku = sl.sku and lli.loc = sl.loc)    
         inner join loc (nolock) on (sl.loc = loc.loc)    
      where sl.storerkey = @cStorerKey     
         and sl.sku = @csku    
         and sl.locationtype not in ('pick', 'case')    
         --and loc.loclevel not in (1, 2)    
         and (lli.qty - lli.qtyallocated - lli.qtypicked) > 0    
         and loc.locationflag not in ('HOLD', 'DAMAGE')    
         and loc.status <> 'HOLD'    
         and lli.loc + lli.ID > @cFromLOCID    
      group by lli.loc + lli.ID, lli.loc, lli.ID    
      order by lli.loc + lli.ID    
    
      if @nQTYAvail is null    
         fetch next from cur_Demand into @cStorerKey, @cSKU, @nQTYtoReplen    
      else    
      begin    
         if @nQTYtoReplen <= @nQTYAvail    
         begin    
            insert into #Replen (storerkey, sku, loc, id, QTY) values (@cStorerKey, @cSKU, @cFromLOC, @cFromID, @nQTYtoReplen)    
            fetch next from cur_Demand into @cStorerKey, @cSKU, @nQTYtoReplen    
         end    
         else    
         begin    
            insert into #Replen (storerkey, sku, loc, id, QTY) values (@cStorerKey, @cSKU, @cFromLOC, @cFromID, @nQTYAvail)    
            set @nQTYtoReplen = @nQTYtoReplen - @nQTYAvail    
         end    
      end    
   end    
   close cur_Demand    
   deallocate cur_Demand    
    
   select d.*, r.*     
   from #demand d    
      left join #replen r on (r.storerkey = d.storerkey and r.sku = d.sku)    
   order by r.loc    
    
END    
    
    

GO