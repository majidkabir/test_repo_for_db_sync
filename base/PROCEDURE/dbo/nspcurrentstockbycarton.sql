SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCurrentStockByCarton                            */
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
/************************************************************************/

CREATE PROC    [dbo].[nspCurrentStockByCarton]
@c_storerkey_Start NVARCHAR(15),
@c_sku_Start	 NVARCHAR(20),
@c_sku_End	 NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   /*-- Current Stock by Carton Report --*/

   select a.storerkey,
   d.company,
   a.sku,
   MAX (b.descr) descr,
   b.packkey,
   --	sum(round(convert(int,a.Qty-a.QtyAllocated-a.QtyPicked)/convert(int,c.casecnt),0)) AS ctn,
   --	sum(convert(int,a.Qty-a.QtyAllocated-a.QtyPicked)/convert(int,c.casecnt)) AS loose_each,
   --	sum(convert(int,a.Qty-a.QtyAllocated-a.QtyPicked)/convert(int,c.qty)) AS loose_each,
   sum(round(a.qty/c.casecnt,0,1)) AS ctn,
   sum(a.qty - (round(a.qty/c.casecnt,0,1) * c.casecnt)) AS loose_each,
   sum(a.qty) as each,
   c.casecnt
   from lotxlocxid a(nolock), sku b(nolock), pack c(nolock), storer d(nolock)
   where a.sku = b.sku
   and a.storerkey = b.storerkey
   and b.PACKKey = c.PACKKey
   and a.storerkey = d.storerkey
   and c.casecnt <> 0
   and a.storerkey = @c_storerkey_Start
   and a.sku >= @c_sku_Start
   and a.sku <= @c_sku_End

   group by a.storerkey, d.company, a.sku, b.packkey, c.casecnt
   order by a.storerkey, a.sku

END


GO