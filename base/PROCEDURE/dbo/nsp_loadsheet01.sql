SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_LoadSheet01                                    */
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

CREATE PROC [dbo].[nsp_LoadSheet01] (
@c_loadkey NVARCHAR(10)
)
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
   orders.billtokey,
   storer.address1,
   storer.address2,
   orders.externorderkey,
   orders.orderdate,
   loadplandetail.adddate,
   orders.invoiceamount,
   orders.orderkey,
   convert(decimal(8,2),loadplandetail.weight),
   convert(decimal(8,2),loadplandetail.[cube]),
   loadplan.trucksize,
   loadplan.route,
   loadplandetail.casecnt,
   loadplan.carrierkey,
   loadplan.driver,
   convert(NVARCHAR(40), loadplan.load_userdef1),
   description=convert(NVARCHAR(45), routemaster.descr)
   from loadplandetail (nolock),
   orders (nolock),
   storer (nolock),
   loadplan (nolock),
   routemaster (nolock)
   where loadplandetail.orderkey = orders.orderkey
   and orders.billtokey = storer.storerkey
   and loadplandetail.loadkey = loadplan.loadkey
   and routemaster.route = orders.route
   and loadplandetail.loadkey = @c_loadkey
   group by loadplandetail.loadkey,
   storer.company,
   orders.billtokey,
   storer.address1,
   storer.address2,
   orders.externorderkey,
   orders.orderdate,
   loadplandetail.adddate,
   orders.invoiceamount,
   orders.orderkey,
   convert(decimal(8,2),loadplandetail.weight),
   convert(decimal(8,2),loadplandetail.[cube]),
   loadplan.trucksize,
   loadplan.route,
   loadplandetail.casecnt,
   loadplan.carrierkey,
   loadplan.driver,
   convert(NVARCHAR(40), loadplan.load_userdef1),
   routemaster.descr
END

GO