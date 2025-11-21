SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_LoadSheet03                                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  286585-PH-Load Sheet Summary Report                        */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver  Purposes                                    */
/* 28-Apr-2015 NJOW01	 1.0  339791-Add trfroom                        */
/* 18-Sep-2015 CSCHONG   1.1  SOS#352276 (CS01)                         */
/* 07-Jun-2016 CSCHONG   1.2  SOS#370665-print by REPORTCOPY setup (CS02)*/
/* 23-Oct-2017 TLTING    1.3  SQl2012 compatiple - group by cude        */
/************************************************************************/

CREATE PROC [dbo].[isp_LoadSheet03] (
@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_invoiceno NVARCHAR(10),
   @c_warehouse NVARCHAR(1),
   @c_prev_warehouse NVARCHAR(1),
   @n_key int

   select loadplandetail.loadkey,
   storer.company,
   loadplandetail.consigneekey,
   isnull(orders.c_address1,'') as c_address1,
   isnull(orders.c_address2,'') as c_address2,
   isnull(orders.c_address3,'') as c_address3,
   isnull(orders.c_address4,'') as c_address4,
   isnull(orders.c_city,'') as c_city,
   loadplandetail.externorderkey,
   convert(datetime, convert(char(8), loadplandetail.adddate, 1)),
   loadplandetail.orderkey,
   orders_casecnt.weight,
   orders_casecnt.cube,
   loadplan.trucksize,
   loadplan.route,
   orders_casecnt.casecnt,
   loadplan.carrierkey,
   orders.userdefine06,
   loadplan.addwho,
   orders.facility,
   facility.descr,
   description=convert(NVARCHAR(45), routemaster.descr),
   facility.userdefine12,
   loadplan.trfroom, --NJOW01
   Loadplan.Route AS LRoute,                                                --(CS01)
   Loadplan.Externloadkey AS LEXTLoadKey,                                   --(CS01) 
   Loadplan.Priority AS LPriority,                                          --(CS01)
   Loadplan.LPuserdefDate01 AS LPuserdefDate01,    --(CS01)  
   pg.Description AS copyname,                    --(CS02)
   pg.code as copycode,                           --(CS02)
   pg.short as copyshowcolumn                     --(CS02)
   from loadplandetail (nolock)
   join loadplan (nolock)on loadplandetail.loadkey = loadplan.loadkey
   join orders (nolock) on loadplandetail.orderkey = orders.orderkey
   join facility (nolock) on orders.facility = facility.facility
   left join routemaster (nolock)on loadplan.route = routemaster.route
   join storer (nolock) on loadplandetail.consigneekey = storer.storerkey
   join (select od.loadkey, od.orderkey, sum((qtyallocated+qtypicked+shippedqty)/p.casecnt)  as casecnt,
         sum((qtyallocated+qtypicked+shippedqty) * s.stdgrosswgt) weight,
         sum((qtyallocated+qtypicked+shippedqty) * ROUND(s.stdcube,6)) cube
         from orderdetail od (nolock)
         join sku s (nolock) on (od.storerkey = s.storerkey and od.sku = s.sku)
         join pack p (nolock) on s.packkey = p.packkey
         join loadplandetail ld (nolock) on ld.loadkey = od.loadkey
         and ld.orderkey = od.orderkey
         where od.loadkey = @c_loadkey
         group by od.loadkey, od.orderkey
         having sum(qtyallocated+qtypicked+shippedqty) > 0  ) as orders_casecnt
   on  orders_casecnt.loadkey = loadplandetail.loadkey
   and orders_casecnt.orderkey = loadplandetail.orderkey
   left join codelkup pg WITH (nolock) on pg.listname = 'REPORTCOPY' and pg.long = 'r_dw_loadsheet03' and pg.storerkey = Orders.Storerkey
   where loadplandetail.loadkey = @c_loadkey
   /*CS02 Start*/
   GROUP BY loadplandetail.loadkey,
   storer.company,
   loadplandetail.consigneekey,
   isnull(orders.c_address1,'') ,
   isnull(orders.c_address2,'') ,
   isnull(orders.c_address3,'') ,
   isnull(orders.c_address4,''),
   isnull(orders.c_city,'') ,
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
   convert(NVARCHAR(45), routemaster.descr),
   facility.userdefine12,
   loadplan.trfroom, 
   Loadplan.Route ,
   Loadplan.Externloadkey ,
   Loadplan.Priority ,
   Loadplan.LPuserdefDate01  , 
   pg.Description ,
   pg.code ,
   pg.short 
   
   /*CS02 END*/
END

GO