SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 2014-Mar-21  TLTING    1.1   SQL20112 Bug                            */

CREATE PROC [dbo].[isp_loadplan_sheet_wave](    
    @c_wavekey NVARCHAR(10)    
 )    
 as     
 begin    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 declare @c_loadkey NVARCHAR(10), 
 		  @c_delivery_zone NVARCHAR(10),    
         @c_load_userdef1 NVARCHAR(200),    
         @n_ordercnt int,    
         @d_adddate datetime,    
         @c_trucksize NVARCHAR(10),    
         @c_storerkey NVARCHAR(15),    
         @c_orderkey NVARCHAR(15),    
         @c_type NVARCHAR(10),    
         @c_company NVARCHAR(45),    
         @c_teamleader NVARCHAR(255),    
         @c_driver NVARCHAR(255),    
         @c_deliveryman NVARCHAR(255),    
         @c_vehicle NVARCHAR(255),    
         @c_descr NVARCHAR(40),    
         @c_pmtterm NVARCHAR(10),  
     	  @c_load_userdef2 NVARCHAR(200) ,
 		  @c_externOrderkey NVARCHAR(30),
 		  @n_drop int,
 		  @n_cube float,
 		  @n_weight float,
       @c_Facility NVARCHAR(5) 

 create table #result(   
    wavekey NVARCHAR(10), 
    loadkey NVARCHAR(10),    
    adddate datetime NULL,    
    teamleader NVARCHAR(255) null,    
    deliveryman NVARCHAR(255) null,    
    trucksize NVARCHAR(10) null,    
    vehicle NVARCHAR(255) null,    
    driver NVARCHAR(255) null,    
    deliveryarea NVARCHAR(10) null,    
    remark NVARCHAR(200) null,   
    ordercnt int null,    
    storerkey NVARCHAR(15) NULL,    
    company NVARCHAR(45) NULL,  
    remark2 NVARCHAR(200) NUll,
    dropcnt int null,
    cube float,
    weight float,
   facility NVARCHAR(5)       
 )    
 -- delete from ids_lp_nested_orderkey    
 /*
 declare cur1 cursor  FAST_FORWARD READ_ONLY   
 for    
 select a.loadkey, a.delivery_zone, convert(char(200), a.load_userdef1), a.ordercnt, a.lpuserdefdate01, a.trucksize, b.storerkey, b.orderkey, b.pmtterm, b.type, c.company,convert(char(200), a.load_userdef2 )  
 from loadplan a (nolock), orders b (nolock), storer c (nolock)    
 where a.loadkey = b.loadkey    
 and b.storerkey = c.storerkey    
 and a.loadkey = @c_loadkey    
 */
 declare cur1 cursor     FAST_FORWARD READ_ONLY
 for    
 select distinct b.Userdefine09, a.delivery_zone, convert(NVARCHAR(200), a.load_userdef1), a.ordercnt, a.lpuserdefdate01, a.trucksize, b.storerkey, c.company, 
	convert(NVARCHAR(200), a.load_userdef2 ), e.stdcube * SUM(f.qtyallocated + f.qtypicked+f.shippedqty), e.stdgrosswgt * SUM(f.qtyallocated + f.qtypicked+f.shippedqty), b.facility
 from loadplan a (nolock)
 RIGHT OUTER JOIN orders b (nolock) ON ( a.loadkey = b.loadkey), storer c (nolock), sku e (nolock), orderdetail f (nolock)
 where  b.storerkey = c.storerkey  
 and b.orderkey = f.orderkey
 and f.storerkey = e.storerkey
 and f.sku = e.sku
 and b.userdefine09 = @c_wavekey
 group by b.Userdefine09, a.delivery_zone, convert(NVARCHAR(200), a.load_userdef1), a.ordercnt, a.lpuserdefdate01, a.trucksize, b.storerkey, c.company, 
	convert(NVARCHAR(200), a.load_userdef2 ), e.stdcube, e.stdgrosswgt, b.facility
 open cur1    
 fetch next from cur1 into @c_loadkey, @c_delivery_zone, @c_load_userdef1, @n_ordercnt, @d_adddate, @c_trucksize, @c_storerkey, @c_company, @c_load_userdef2 , @n_cube, @n_weight, @c_facility 
 SELECT @n_drop = COUNT(DISTINCT consigneekey)
 FROM ORDERS (NOLOCK)
 WHERE loadkey = @c_loadkey
 while (@@fetch_status=0)    
    begin    
 --      SELECT @c_externorderkey = EXTERNORDERKEY 
 --      FROM ORDERS (NOLOCK)
 --      WHERE ORDERKEY = @c_orderkey
 --      if @c_pmtterm = 'COD'    
 --         set @c_externorderkey = '*' + @c_externorderkey + ' (' +  dbo.fnc_LTrim(dbo.fnc_RTrim(@c_type)) + ')'    
 --      insert into ids_lp_nested_orderkey    
 --      values(@c_orderkey, @c_storerkey)    
       insert into #result   
      values(@c_wavekey, @c_loadkey, @d_adddate, @c_teamleader, @c_deliveryman, @c_trucksize, @c_vehicle, @c_driver, @c_delivery_zone, @c_load_userdef1, @n_ordercnt, @c_storerkey, @c_company, @c_load_userdef2, @n_drop, @n_cube, @n_weight, @c_facility)          
    
      fetch next from cur1 into @c_loadkey, @c_delivery_zone, @c_load_userdef1, @n_ordercnt, @d_adddate, @c_trucksize, @c_storerkey, @c_company, @c_load_userdef2 , @n_cube, @n_weight, @c_facility 
    end    
 close cur1    
 deallocate cur1    
 /**    
    Cur2 - to get team leader    
 **/    
 declare cur2 cursor     FAST_FORWARD READ_ONLY
 for    
 select e.description    
 from ids_lp_driver d (nolock), codelkup e (nolock)    
 where d.drivercode = e.code    
 and d.loadkey = @c_loadkey    
 and e.listname = 'Driver'    
 and e.short = 'TL'    
 and e.long = 'Team Leader'    
 open cur2    
 fetch next from cur2 into @c_descr    
 while(@@fetch_status=0)    
    begin    
 	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_teamleader)) <> ''
 	SELECT @c_teamleader = @c_teamleader + ' / '
       	set @c_teamleader = @c_teamleader + dbo.fnc_RTrim(@c_descr) -- + ' / '    
       	fetch next from cur2 into @c_descr    
    end    
 close cur2    
 deallocate cur2    
 update #result    
 set teamleader = @c_teamleader
 --substring(@c_teamleader,1,len(@c_teamleader)-3)    
 /**    
    End of getting team leader    
 **/    
 /**    
    Cur3 - to get delivery man    
 **/    
 declare cur3 cursor     FAST_FORWARD READ_ONLY
 for    
 select dbo.fnc_LTrim(dbo.fnc_RTrim(e.description))    
 from ids_lp_driver d (nolock), codelkup e (nolock)    
 where d.drivercode = e.code    
 and d.loadkey = @c_loadkey    
 and e.listname = 'Driver'    
 and e.short = 'DM'    
 and e.long = 'Delivery Man'    
 open cur3    
 fetch next from cur3 into @c_descr    
 while(@@fetch_status=0)    
    begin    
 	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_deliveryman)) <> ''
 	SELECT @c_deliveryman = @c_deliveryman + ' / '
         set @c_deliveryman =    @c_deliveryman + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_descr)) -- + ' / '
         fetch next from cur3 into @c_descr    
    end    
 close cur3    
 deallocate cur3    
 update #result    
 set deliveryman = @c_deliveryman 
 --substring(@c_deliveryman,1,len(@c_deliveryman)-3)    
 /**    
    End of getting delivery man    
 **/    
 /**    
    Cur4 - to get driver    
 **/    
 declare cur4 cursor     FAST_FORWARD READ_ONLY
 for    
 select dbo.fnc_LTrim(dbo.fnc_RTrim(e.description))    
 from ids_lp_driver d (nolock), codelkup e (nolock)    
 where d.drivercode = e.code    
 and d.loadkey = @c_loadkey    
 and e.listname = 'Driver'    
 and e.short = 'DR'    
 and e.long = 'Driver'    
 open cur4    
 fetch next from cur4 into @c_descr    
 while(@@fetch_status=0)    
    begin    
 		IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_driver)) <> ''
 			SELECT @c_driver = @c_driver + ' / '
       set @c_driver =    @c_driver + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_descr)) -- + ' / '
       fetch next from cur4 into @c_descr    
    end    
 close cur4    
 deallocate cur4    
 update #result    
 set driver = @c_driver -- substring(@c_driver,1,len(@c_driver)-3)    
 /**    
  End of getting driver    
 **/    
 declare cur5 cursor     FAST_FORWARD READ_ONLY
 for    
 select dbo.fnc_LTrim(dbo.fnc_RTrim(vehiclenumber)) from ids_lp_vehicle(nolock)    
 where loadkey = @c_loadkey    
 order by linenumber    
 open cur5    
 fetch next from cur5 into @c_descr    
 while (@@fetch_status=0)    
    begin    
 		IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehicle)) <> ''
 			SELECT @c_vehicle = @c_vehicle + ' / '
       set @c_vehicle = @c_vehicle + dbo.fnc_RTrim(@c_descr) -- + ' / '    
       fetch next from cur5 into @c_descr    
    end    
 close cur5    
 deallocate cur5    
 update #result    
 set vehicle = '*' + @c_vehicle -- substring(@c_vehicle,1,len(@c_vehicle)-3)    
 select convert(NVARCHAR(30), Suser_Sname()) 'user_name', * from #result    
 --select * from #result    
 --Select convert(char(30), user_name()) 'user_name',  
 /*  
 Select loadkey,  
  adddate,  
  teamleader,  
  deliveryman,  
  trucksize,  
  vehicle,  
  driver,  
  deliveryarea,  
  remark,  
  ordercnt,  
  storerkey,  
  company,  
  remark2,  
  orderkey  
 From #result  
 */  
 drop table #result    
 SET NOCOUNT OFF  
 END

GO