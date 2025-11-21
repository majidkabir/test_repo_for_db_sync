SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_LoadSheet_CMC                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Date         Author        Purposes                                  */
/* 01-Jun-2007  Leong         SOS77466 Recalculate Weight and Cube      */
/* 01-Sept-2007 Leong         SOS85340 Round Sku.StdCube                */
/* 04-MAR-2014  YTWan         SOS#303595 - PH - Update Loading Sheet RCM*/
/*                            (Wan01)                                   */
/* 14-Sep-2015  CSCHONG       SOS#352276 (CS01)                         */
/* 12-Oct-2018  LZG           INC0423908 - Round casecnt to 2 decimal   */
/*                            places (ZG01)                             */
/************************************************************************/

CREATE PROC [dbo].[nsp_LoadSheet_CMC] (
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
   --(Wan01) - START
         , @c_IDS_Company  NVARCHAR(45)

   SET  @c_IDS_Company = ''

   SELECT @c_IDS_Company = ISNULL(RTRIM(Company),'')
   FROM STORER WITH (NOLOCK)
   WHERE Storerkey = 'IDS'

   IF @c_IDS_Company = ''
   BEGIN
      SET @c_IDS_Company = 'LF (Philippines), Inc.'
   END
   --(Wan01) - END

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
   ROUND(orders_casecnt.casecnt, 2),              -- ZG01
   loadplan.carrierkey,
   orders.userdefine06,
   loadplan.addwho,
   orders.facility,
   facility.descr,
   description=convert(NVARCHAR(45), routemaster.descr)
   , @c_IDS_Company,                       --(Wan01)
   Loadplan.Route AS LRoute,                       --(CS01)
   Loadplan.Externloadkey AS LEXTLoadKey,                --(CS01)
   Loadplan.Priority AS LPriority,                      --(CS01)
   Loadplan.LPuserdefDate01 AS LPuserdefDate01    --(CS01)
   from loadplandetail  WITH (nolock)
   join loadplan WITH (nolock)on loadplandetail.loadkey = loadplan.loadkey
   join orders   WITH (nolock) on loadplandetail.orderkey = orders.orderkey
   join facility WITH (nolock) on orders.facility = facility.facility
   join routemaster WITH (nolock)on loadplan.route = routemaster.route
   join storer      WITH (nolock) on loadplandetail.consigneekey = storer.storerkey
   join (select od.loadkey, od.orderkey, sum((qtyallocated+qtypicked+shippedqty)/p.casecnt)  as casecnt,
         -- SOS77466
         --ld.weight, ld.cube
         sum((qtyallocated+qtypicked+shippedqty) * s.stdgrosswgt) weight,
         sum((qtyallocated+qtypicked+shippedqty) * ROUND(s.stdcube,6)) cube -- SOS85340
         from orderdetail od WITH (nolock)
         join sku s  WITH (nolock) on (od.storerkey = s.storerkey and od.sku = s.sku)
         join pack p WITH (nolock) on s.packkey = p.packkey
         join loadplandetail ld WITH (nolock) on ld.loadkey = od.loadkey
         and ld.orderkey = od.orderkey
         where od.loadkey = @c_loadkey
         group by od.loadkey, od.orderkey
         having sum(qtyallocated+qtypicked+shippedqty) > 0  ) as orders_casecnt
   on  orders_casecnt.loadkey = loadplandetail.loadkey
   and orders_casecnt.orderkey = loadplandetail.orderkey
   where loadplandetail.loadkey = @c_loadkey
END

GO