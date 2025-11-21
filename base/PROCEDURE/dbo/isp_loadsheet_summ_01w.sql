SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Stored Procedure: isp_LoadSheet_Summ_01w                             */    
/* Creation Date: 08/08/2014                                            */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: 315657 - PH - GSK Load Sheet Summary                        */    
/*                                                                      */    
/* Called By: Wave                                                      */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/*Date         Author  Ver. Purposes                                    */   
/*24-Sep-2015  CSCHONG 1.1  SOS#352276 (CS01)                           */   
/* 25-JAN-2017  JayLim   1.2  SQL2012 compatibility modification (Jay01)*/  
/************************************************************************/    
    
CREATE PROC [dbo].[isp_LoadSheet_Summ_01w] (    
@c_wavekey NVARCHAR(10))    
AS    
BEGIN    
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @c_invoiceno NVARCHAR(10),    
           @c_warehouse NVARCHAR(1),    
           @c_prev_warehouse NVARCHAR(1),    
           @n_key INT,    
           @c_IDS_Company  NVARCHAR(45)    
    
   SET  @c_IDS_Company = ''    
    
   SELECT @c_IDS_Company = ISNULL(RTRIM(Company),'')    
   FROM STORER WITH (NOLOCK)    
   WHERE Storerkey = 'IDS'    
    
   IF @c_IDS_Company = ''    
   BEGIN    
      SET @c_IDS_Company = 'LF (Philippines), Inc.'    
   END    
    
   select loadplandetail.loadkey,    
   storer.company,    
   loadplandetail.consigneekey,    
   storer.address1,    
   storer.address2,    
   storer.address3,    
   loadplandetail.externorderkey,    
   convert(datetime, convert(char(8), loadplandetail.adddate, 1)),    
   loadplandetail.orderkey,    
   orders_casecnt.weight,    
   orders_casecnt.[cube],    
   loadplan.trucksize,    
   loadplan.route,    
   orders_casecnt.casecnt,    
   loadplan.carrierkey,    
   orders.userdefine06,    
   loadplan.addwho,    
   orders.facility,    
   facility.descr,    
   description=convert(NVARCHAR(45), routemaster.descr),    
   @c_IDS_Company,    
   orders_casecnt.looseqty,    
   orders_casecnt.totalqty,    
   orders_casecnt.totalsku,  
   Loadplan.Externloadkey AS LEXTLoadKey,                                   --(CS01)   
   Loadplan.Priority AS LPriority,                                          --(CS01)  
   Loadplan.LPuserdefDate01 AS LPuserdefDate01    --(CS01)                             
   from loadplandetail  WITH (nolock)    
   join loadplan WITH (nolock)on loadplandetail.loadkey = loadplan.loadkey    
   join orders   WITH (nolock) on loadplandetail.orderkey = orders.orderkey    
   join facility WITH (nolock) on orders.facility = facility.facility    
   left join routemaster WITH (nolock)on loadplan.route = routemaster.route    
   join storer      WITH (nolock) on loadplandetail.consigneekey = storer.storerkey    
   join (select od.loadkey, od.orderkey,     
         floor(sum( CASE WHEN p.casecnt > 0 THEN (qtyallocated+qtypicked+shippedqty)/p.casecnt ELSE 0 END)) as casecnt,    
         sum((qtyallocated+qtypicked+shippedqty) * s.stdgrosswgt) weight,    
     sum((qtyallocated+qtypicked+shippedqty) * ROUND(s.stdcube,6)) AS 'cube',    
         sum(qtyallocated+qtypicked+shippedqty) as totalqty,    
         sum( CASE WHEN p.casecnt > 0 THEN (qtyallocated+qtypicked+shippedqty) % CAST(p.casecnt AS INT) ELSE (qtyallocated+qtypicked+shippedqty) END) AS looseqty,    
         count(DISTINCT od.sku) AS totalsku    
         FROM orders o (NOLOCK)     
         join orderdetail od WITH (nolock) ON (o.orderkey = od.orderkey)    
         join sku s  WITH (nolock) on (od.storerkey = s.storerkey and od.sku = s.sku)    
         join pack p WITH (nolock) on s.packkey = p.packkey    
         join loadplandetail ld WITH (nolock) on ld.loadkey = od.loadkey    
                                              and ld.orderkey = o.orderkey    
         where o.userdefine09 = @c_wavekey    
         group by od.loadkey, od.orderkey    
         having sum(qtyallocated+qtypicked+shippedqty) > 0  ) as orders_casecnt    
   on  orders_casecnt.loadkey = loadplandetail.loadkey    
   and orders_casecnt.orderkey = loadplandetail.orderkey    
   where orders.userdefine09 = @c_wavekey    
END  

GO