SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_loadplan_manifest_batch                        */  
/* Creation Date:  25-Sept-2003                                         */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Report                                                      */  
/*                                                                      */  
/* Input Parameters:  @c_loadkey  - (Loadplan Number)                   */  
/*                    @c_Storerkey     - (Storerkey)                    */  
/*                    @c_Facility      - (Default Facility)             */  
/*                    @cDiscreteOrder  - (Value "Y" or "N")             */  
/*           (All the parameters are setup in the Configuration file,   */  
/*            C:\WINNT\NIKEREGDTS.INI)                                  */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 10-Oct-2006  Shong     Allow the AddDate With NULL                   */  
/* 22-Feb-2017  CSCHONG   Add new field (CS01)                          */        
/************************************************************************/  
  
CREATE PROC [dbo].[isp_loadplan_manifest_batch](  
   @c_loadkey NVARCHAR(10)  
)  
as   
begin  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
DECLARE @c_teamleader NVARCHAR(255),  
        @c_description NVARCHAR(255),  
        @c_deliveryman NVARCHAR(255),  
        @c_driver NVARCHAR(255),  
        @c_short NVARCHAR(18),  
        @c_long NVARCHAR(250),  
        @c_vehiclenumber NVARCHAR(10),  
        @c_vehiclenos NVARCHAR(255),  
        @n_batch int,  
        @n_vehiclecnt int  
  
  
create table #result(  
   loadkey NVARCHAR(10),  
   allocated NVARCHAR(1) null,  
   adddate datetime null,  
   teamleader NVARCHAR(255) null,  
   deliveryman NVARCHAR(255) null,  
   vehicle NVARCHAR(255) null,  
   vehicletype NVARCHAR(20) null,  
   vehiclecnt int null,   
   driver NVARCHAR(255) null,  
   trucksize NVARCHAR(10) null,   
   trfroom NVARCHAR(10) null,  -- Modified by YokeBeen on 07-Oct-2002 (SOS# 7632)  
   delivery_zone NVARCHAR(10) null,  
   remark NVARCHAR(16) null,  
   sku NVARCHAR(20) null,  
   descr NVARCHAR(60) null,  
   itemclass NVARCHAR(250) null,  
   packkey NVARCHAR(10) null,  
   pack_casecnt int null,  
   capacity float(8) null,  
   grossweight float(8) null,  
   totalqty int null,  
   total_ctn int null,  
   total_pc int null,  
   username NVARCHAR(255) null,  
   pack_innerpack int null,  
   total_inner int null,  
   PACKdescr NVARCHAR(45) NULL,  
   ExtLoadKey   NVARCHAR(30) NULL                 --CS01  
)  
  
insert into #result (loadkey,   
   allocated,    
   adddate,   
   trucksize,  
   trfroom,   
   delivery_zone,   
   remark,   
   sku,   
   descr,  
   itemclass,  
   packkey,   
   pack_casecnt,  
   capacity,  
   grossweight,  
   totalqty,  
   username,  
   pack_innerpack,  
   packdescr,  
   ExtLoadKey                    --(CS01)  
)  
SELECT LoadPlan.LoadKey,     
       Orders.UserDefine08,  
  LoadPlan.lpuserdefdate01,     
       LoadPlan.TruckSize,     
       LoadPlan.TrfRoom,     
       LoadPlan.Delivery_Zone,     
       remark = convert(NVARCHAR(255),LoadPlan.Load_UserDef1),     
       ORDERDETAIL.Sku,     
       SKU.DESCR,     
       Codelkup.Description,  
       PACK.Packkey,   
       p_casecnt = PACK.CaseCnt,    
       SKU.StdCube,     
       SKU.stdgrosswgt,  
       qty = sum(ORDERDETAIL.QtyAllocated+ORDERDETAIL.QtyPicked+ORDERDETAIL.ShippedQty),  
       username = Suser_Sname(),  
       PACK.InnerPack,  
       PACK.Packdescr  
       ,LoadPlan.ExternLoadKey                                         --CS01  
FROM LoadPlan (nolock),     
     ORDERDETAIL (nolock),     
     ORDERS (nolock),     
     PACK (nolock),     
     SKU (nolock),  
     CODELKUP (nolock)   
WHERE ( LoadPlan.LoadKey = ORDERS.LoadKey ) and    
      ( ORDERS.OrderKey = ORDERDETAIL.OrderKey ) and    
      ( ORDERDETAIL.Storerkey = SKU.Storerkey ) and  
      ( ORDERDETAIL.Sku = SKU.Sku ) and    
      ( ORDERDETAIL.PackKey = PACK.PackKey ) and  
      ( SKU.itemclass = Codelkup.Code ) and  
      ( Codelkup.listname = 'ITEMCLASS' ) and  
      ( ORDERS.UserDefine08 = 'N') and  
      ( LOADPLAN.LoadKey = @c_loadkey)     
GROUP BY LoadPlan.LoadKey,     
      Orders.UserDefine08,  
      LoadPlan.lpuserdefdate01,     
      LoadPlan.TruckSize,     
      LoadPlan.TrfRoom,     
      LoadPlan.Delivery_Zone,     
      convert(NVARCHAR(255),LoadPlan.Load_UserDef1),     
      ORDERDETAIL.Sku,     
      SKU.DESCR,     
      Codelkup.Description,  
      PACK.Packkey,  
      PACK.CaseCnt,  
      SKU.StdCube,     
      SKU.stdgrosswgt,  
      PACK.Innerpack,  
      PACK.Packdescr  
  ,LoadPlan.ExternLoadKey   
  
/*  
update #result  
set total_ctn = 0, total_pc = totalqty  
where pack_casecnt = 0  
  
update #result  
set total_ctn = floor(totalqty/pack_casecnt),total_pc = totalqty % cast(pack_casecnt as int)  
where totalqty >= pack_casecnt and  
      pack_casecnt > 0  
  
update #result  
set total_ctn = totalqty,total_pc = 0  
where totalqty < pack_casecnt and  
      pack_casecnt > 0  
*/  
  
update #result  
set total_ctn = CASE WHEN pack_casecnt = 0 THEN 0  
           ELSE floor(totalqty/pack_casecnt)  
      END,   
    total_inner = CASE  WHEN pack_innerpack = 0 THEN 0  
         WHEN pack_innerpack > 0 and pack_casecnt = 0   
            THEN floor(totalqty / pack_innerpack)  
         ELSE floor((totalqty % cast(pack_casecnt as Int))/pack_innerpack)  
        END,  
    total_pc = 0  
  
update #result  
set total_pc = totalqty - (total_ctn*pack_casecnt) - (total_inner*pack_innerpack)  
  
/*Start - Get drivers (team leader, deliver man, and driver) from codelkup table */  
declare cur1 cursor LOCAL FAST_FORWARD READ_ONLY for  
select b.description, b.short, b.long   
from ids_lp_driver a (nolock), codelkup b (nolock)  
where a.drivercode = b.code  
and b.listname='Driver'  
and b.short in ('TL','DM','DR')  
and b.long in ('Team Leader','Delivery Man','Driver')  
and a.loadkey=@c_loadkey  
  
open cur1  
  
fetch next from cur1 into @c_description, @c_short, @c_long  
  
while (@@fetch_status=0)  
   begin  
      if dbo.fnc_RTrim(@c_short)='TL' and dbo.fnc_RTrim(@c_long)='Team Leader'  
         begin  
            set @c_teamleader = @c_teamleader + dbo.fnc_RTrim(@c_description) + ' / '  
         end  
      else if dbo.fnc_RTrim(@c_short)='DM' and dbo.fnc_RTrim(@c_long)='Delivery Man'  
         begin  
            set @c_deliveryman = @c_deliveryman + dbo.fnc_RTrim(@c_description) + ' / '  
         end  
      else if dbo.fnc_RTrim(@c_short)='DR' and dbo.fnc_RTrim(@c_long)='Driver'  
          begin  
             set @c_driver = @c_driver + dbo.fnc_RTrim(@c_description) + ' / '  
          end  
      fetch next from cur1 into @c_description, @c_short, @c_long  
   end  
  
close cur1  
deallocate cur1  
  
update #result  
set teamleader = @c_teamleader  
  
update #result  
set deliveryman = @c_deliveryman  
  
  
update #result  
set driver = @c_driver  
/*End - Get drivers (team leader, deliver man, and driver) from codelkup table */  
  
-- start: get vehicle numbers  
DECLARE cur2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
select a.vehiclenumber   
from ids_lp_vehicle a (nolock), ids_vehicle b (nolock)  
where a.loadkey = @c_loadkey  
and a.vehiclenumber = b.vehiclenumber  
order by linenumber  
  
open cur2  
  
select @n_vehiclecnt = 0  
fetch next from cur2 into @c_vehiclenumber  
  
while (@@fetch_status=0)  
begin  
   select @n_vehiclecnt = @n_vehiclecnt + 1  
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehiclenos)) <> ''  
      SELECT @c_vehiclenos = @c_vehiclenos + ' / '  
  
   set @c_vehiclenos =    @c_vehiclenos + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehiclenumber)) -- + ' / '  
  
   fetch next from cur2 into @c_vehiclenumber  
end  
  
close cur2  
deallocate cur2  
-- end: get vehicle numbers  
  
update #result  
set vehicle = '*' + @c_vehiclenos,  
    vehiclecnt = @n_vehiclecnt  
  
-- start: get the major vehicle type  
update #result  
set vehicletype = b.vehicletype  
from ids_lp_vehicle a (nolock), ids_vehicle b (nolock)  
where a.loadkey=@c_loadkey  
and a.vehiclenumber = b.vehiclenumber  
and a.linenumber = '00001'  
-- end: get the major vehicle type  
  
-- get the no of batch orders  
select @n_batch = count(*)  
from orders (nolock), loadplan (nolock)   
where orders.loadkey = loadplan.loadkey and  
      dbo.fnc_RTrim(orders.userdefine08) = 'N' and  
      loadplan.loadkey = @c_loadkey  
  
select *, @n_batch from #result  
  
drop table #result  
  
end -- end of procedure  

GO