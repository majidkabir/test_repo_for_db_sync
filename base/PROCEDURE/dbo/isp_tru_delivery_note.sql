SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */

CREATE proc [dbo].[isp_tru_delivery_note](  
   @c_loadkey NVARCHAR(10)  
)  
as   
begin  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
declare @c_delivery_zone NVARCHAR(10),  
        @d_adddate datetime,  
        @c_trucksize NVARCHAR(10),  
        @c_storerkey NVARCHAR(15),  
        @c_gangleader NVARCHAR(255),  
        @c_driver NVARCHAR(255),  
        @c_deliveryman NVARCHAR(255),  
        @c_vehicle NVARCHAR(255),  
        @c_descr NVARCHAR(250),  
        @c_load_userdef1 NVARCHAR(16),  
        @c_consigneekey NVARCHAR(15),  
        @c_company NVARCHAR(45),  
        @c_add1 NVARCHAR(45),  
        @c_add2 NVARCHAR(45),  
        @c_add3 NVARCHAR(45),  
        @c_add4 NVARCHAR(45),  
        @c_phone NVARCHAR(18),  
        @c_buyerpo NVARCHAR(20),  
        @c_externorderkey NVARCHAR(50),     --tlting_ext
        @c_sku NVARCHAR(20),  
        @c_manufacturersku NVARCHAR(20),  
        @c_zonecategory NVARCHAR(10),  
        @c_busr6 NVARCHAR(30),  
        @c_skudescr NVARCHAR(60),  
        @c_packkey NVARCHAR(10),  
        @f_casecnt float(8),  
        @f_qty float(8),  
        @n_qtypicked int,  
        @n_qtyallocated int,  
        @f_total_cubage float(8),  
        @f_total_weight float(8),  
        @n_novehicle int  
  
create table #result(  
   loadkey NVARCHAR(10),  
   adddate datetime,  
   gangleader NVARCHAR(255) null,  
   deliveryman NVARCHAR(255) null,  
   trucksize NVARCHAR(10) null,  
   vehicle NVARCHAR(255) null,  
   driver NVARCHAR(255) null,  
   deliveryarea NVARCHAR(10) null,  
   remark NVARCHAR(16) null,  
   consigneekey NVARCHAR(15) null,  
   company NVARCHAR(45) null,  
   add1 NVARCHAR(45) null,  
   add2 NVARCHAR(45) null,  
   add3 NVARCHAR(45) null,  
   add4 NVARCHAR(45) null,  
   phone NVARCHAR(18) null,  
   buyerpo  NVARCHAR(20) null,  
   externorderkey NVARCHAR(50) null,   --tlting_ext
   sku NVARCHAR(20) null,  
   manufacturersku NVARCHAR(20) null,  
   zonecategory NVARCHAR(10) null,  
   busr6 NVARCHAR(30) null,  
   descr NVARCHAR(60) null,  
   packkey NVARCHAR(10) null,  
   casecnt float(8) null,  
   qty float(8) null,  
   qtypicked int null,    
   qtyallocated int null  
)  
  
  
  
declare cur1 cursor FAST_FORWARD READ_ONLY  
for  
select a.loadkey,   
       a.adddate,   
       a.delivery_zone,   
       a.trucksize,   
       cast(a.load_userdef1 as NVARCHAR(16)),   
       b.consigneekey,   
       b.c_company,   
       b.c_address1,   
       b.c_address2,   
       b.c_address3,   
       b.c_address4,   
       b.c_phone1,   
       b.buyerpo,   
       b.externorderkey,  
       c.sku,  
       d.manufacturersku,  
       e.zonecategory,  
       d.busr6,  
       d.descr,  
       c.packkey,  
       c.qtypicked,  
       c.qtyallocated,  
       f.casecnt,  
       f.qty  
from loadplan a (nolock), orders b (nolock), orderdetail c (nolock), sku d (nolock), putawayzone e (nolock), pack f (nolock)  
where a.loadkey = b.loadkey  
and b.orderkey = c.orderkey  
and c.sku = d.sku
AND C.Storerkey = D.Storerkey  
and d.packkey = f.packkey  
and d.putawayzone = e.putawayzone  
and a.loadkey = @c_loadkey  
AND B.Storerkey = '11307' -- TRU storer only.
  
open cur1  
  
fetch next from cur1 into @c_loadkey,   
                          @d_adddate,   
                          @c_delivery_zone,   
                          @c_trucksize,   
                          @c_load_userdef1,   
                          @c_consigneekey,  
                          @c_company,  
                          @c_add1,  
                          @c_add2,  
                          @c_add3,  
                          @c_add4,  
                          @c_phone,  
                          @c_buyerpo,  
                          @c_externorderkey,  
                          @c_sku,  
                          @c_manufacturersku,  
                          @c_zonecategory,  
                          @c_busr6,  
                          @c_skudescr,  
                          @c_packkey,  
                          @n_qtypicked,  
                          @n_qtyallocated,  
                          @f_casecnt,  
                          @f_qty  
  
while (@@fetch_status=0)  
   begin  
  
      insert into #result(loadkey,  
                          adddate,  
                          deliveryarea,  
                          trucksize,  
                          remark,  
                          consigneekey,  
            company,  
                          add1,  
                          add2,  
                          add3,  
                          add4,  
                          phone,  
                          buyerpo,  
                          externorderkey,  
                          sku,  
                          manufacturersku,  
                          zonecategory,  
                          busr6,                                               
                          descr,  
                          packkey,  
                          casecnt,  
                          qty)  
      values(@c_loadkey,   
             @d_adddate,   
             @c_delivery_zone,   
             @c_trucksize,   
             @c_load_userdef1,   
             @c_consigneekey,  
             @c_company,  
             @c_add1,  
             @c_add2,  
             @c_add3,  
             @c_add4,  
             @c_phone,  
             @c_buyerpo,  
             @c_externorderkey,  
             @c_sku,  
             @c_manufacturersku,  
             @c_zonecategory,  
             @c_busr6,  
             @c_skudescr,  
             @c_packkey,  
             @f_casecnt,  
             @f_qty)  
  
      fetch next from cur1 into @c_loadkey,   
                                @d_adddate,   
                                @c_delivery_zone,   
                                @c_trucksize,   
                                @c_load_userdef1,   
                                @c_consigneekey,  
                                @c_company,  
                                @c_add1,  
                                @c_add2,  
                                @c_add3,  
                                @c_add4,  
                                @c_phone,  
                                @c_buyerpo,  
                                @c_externorderkey,  
                                @c_sku,  
                                @c_manufacturersku,  
                                @c_zonecategory,  
                                @c_busr6,  
                                @c_descr,  
                                @c_packkey,  
                                @n_qtypicked,  
                                @n_qtyallocated,  
                                @f_casecnt,  
                                @f_qty  
  
   end  
  
close cur1  
deallocate cur1  
  
/**  
   Cur2 - to get gang leader  
**/  
declare cur2 cursor  FAST_FORWARD READ_ONLY
for  
select e.description  
from ids_lp_driver d (nolock), codelkup e (nolock)  
where d.drivercode = e.code  
and d.loadkey = @c_loadkey  
and e.listname = 'Driver'  
and e.short = 'G'  
and e.long = 'Gang Leader'  
  
open cur2  
  
fetch next from cur2 into @c_descr  
  
while(@@fetch_status=0)  
   begin  
      set @c_gangleader = @c_gangleader + dbo.fnc_RTrim(@c_descr) + ' / '  
      fetch next from cur2 into @c_descr  
   end  
  
close cur2  
deallocate cur2  
  
  
update #result  
set gangleader = substring(@c_gangleader,1,len(@c_gangleader)-3)  
  
/**  
   End of getting gang leader  
**/  
  
  
  
/**  
   Cur3 - to get delivery man  
**/  
declare cur3 cursor FAST_FORWARD READ_ONLY 
for  
select e.description  
from ids_lp_driver d (nolock), codelkup e (nolock)  
where d.drivercode = e.code  
and d.loadkey = @c_loadkey  
and e.listname = 'Driver'  
and e.short = 'D'  
and e.long = 'Delivery Man'  
  
open cur3  
  
fetch next from cur3 into @c_descr  
  
while(@@fetch_status=0)  
   begin  
      set @c_deliveryman = @c_deliveryman + dbo.fnc_RTrim(@c_descr) + ' / '  
      fetch next from cur3 into @c_descr  
   end  
  
close cur3  
deallocate cur3  
  
update #result  
set deliveryman = substring(@c_deliveryman,1,len(@c_deliveryman)-3)  
  
/**  
   End of getting delivery man  
**/  
  
  
  
/**  
   Cur4 - to get driver  
**/  
declare cur4 cursor  FAST_FORWARD READ_ONLY
for  
select e.description  
from ids_lp_driver d (nolock), codelkup e (nolock)  
where d.drivercode = e.code  
and d.loadkey = @c_loadkey  
and e.listname = 'Driver'  
and e.short = 'R'  
and e.long = 'Driver'  
  
open cur4  
  
fetch next from cur4 into @c_descr  
  
while(@@fetch_status=0)  
   begin  
      set @c_driver = @c_driver + dbo.fnc_RTrim(@c_descr) + ' / '  
      fetch next from cur4 into @c_descr  
   end  
  
close cur4  
deallocate cur4  
  
update #result  
set driver = substring(@c_driver,1,len(@c_driver)-3)  
  
/**  
   End of getting driver  
**/  
  
declare cur5 cursor FAST_FORWARD READ_ONLY  
for  
select vehiclenumber from ids_lp_vehicle(nolock)  
where loadkey = @c_loadkey  
order by linenumber  
  
open cur5  
   
fetch next from cur5 into @c_descr  
  
while (@@fetch_status=0)  
   begin  
      set @c_vehicle = @c_vehicle + dbo.fnc_RTrim(@c_descr) + ' / '  
      fetch next from cur5 into @c_descr  
   end  
  
close cur5  
deallocate cur5  
  
update #result  
set vehicle = '*' + substring(@c_vehicle,1,len(@c_vehicle)-3)  
  
-- get total cubage  
select @f_total_cubage = sum(capacity)  
from orders (nolock)  
where loadkey = @c_loadkey  
  
-- get total weight  
select @f_total_weight = sum(grossweight)  
from orders (nolock)  
where loadkey = @c_loadkey  
  
-- get total vehicle  
select @n_novehicle = count(*) from ids_lp_vehicle(nolock)  
where loadkey = @c_loadkey  
  
select Suser_Sname(),*, @f_total_cubage, @f_total_weight, @n_novehicle from #result  
  
drop table #result  
  
end

GO