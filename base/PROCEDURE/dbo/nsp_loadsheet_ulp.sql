SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_LoadSheet_ulp                                  */
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
/* 24-Mar-2014  TLTING   1.1  SQL2012 Bug                               */
/************************************************************************/

CREATE PROC [dbo].[nsp_LoadSheet_ulp] (
@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_invoiceno NVARCHAR(10),
   @c_warehouse NVARCHAR(1),
   @c_prev_warehouse NVARCHAR(1),
   @n_key int

   select loadplandetail.loadkey,
   storer.company,
   loadplandetail.consigneekey,
   storer.address1,
   storer.address2,
   loadplandetail.externorderkey,
   loadplandetail.orderdate,
   convert(datetime, convert(NVARCHAR(8), loadplandetail.adddate, 1)),
   0,
   loadplandetail.orderkey,
   orders_casecnt.weight,
   orders_casecnt.[cube],
   loadplan.trucksize,
   loadplan.route,
   orders_casecnt.casecnt,
   loadplan.carrierkey,
   loadplan.driver,
   convert(NVARCHAR(40), loadplan.load_userdef1),
   description=convert(NVARCHAR(45), routemaster.descr)
   from loadplandetail (nolock) join loadplan (nolock)
   on loadplandetail.loadkey = loadplan.loadkey
   join routemaster (nolock)
   on loadplan.route = routemaster.route
   join storer (nolock)
   on loadplandetail.consigneekey = storer.storerkey
   join (select od.loadkey, od.orderkey, sum((qtyallocated+qtypicked+shippedqty)/p.casecnt)  as casecnt,
   ld.weight, ld.[cube]
   from orderdetail od (nolock) join pack p (nolock)
   on od.packkey = p.packkey
   join loadplandetail ld (nolock)
   on ld.loadkey = od.loadkey
   and ld.orderkey = od.orderkey
   where od.loadkey = @c_loadkey
   group by od.loadkey, od.orderkey, weight, ld.[cube]) as orders_casecnt
   on orders_casecnt.loadkey = loadplandetail.loadkey
   and orders_casecnt.orderkey = loadplandetail.orderkey
   where loadplandetail.loadkey = @c_loadkey
   group by loadplandetail.loadkey,
   storer.company,
   loadplandetail.consigneekey,
   storer.address1,
   storer.address2,
   loadplandetail.externorderkey,
   loadplandetail.orderdate,
   convert(datetime, convert(NVARCHAR(8), loadplandetail.adddate, 1)),
   loadplandetail.orderkey,
   orders_casecnt.weight,
   orders_casecnt.[cube],
   loadplan.trucksize,
   loadplan.route,
   orders_casecnt.casecnt,
   loadplan.carrierkey,
   loadplan.driver,
   convert(NVARCHAR(40), loadplan.load_userdef1),
   routemaster.descr
END

GO