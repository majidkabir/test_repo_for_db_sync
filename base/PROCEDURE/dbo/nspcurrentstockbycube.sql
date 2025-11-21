SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCurrentStockByCube                              */
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
/* 10-MAR-2017  JayLim   1.1  SQL2012 compatibility modification (Jay01)*/ 
/************************************************************************/

CREATE PROC    [dbo].[nspCurrentStockByCube]
@c_storerkey_Start NVARCHAR(15),
@c_sku_Start	 NVARCHAR(20),
@c_sku_End	 NVARCHAR(20),
@c_itemclass_Start NVARCHAR(10),
@c_itemclass_End NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   /* Current Stock by Cube Report --*/
   select a.storerkey,
   d.company,
   a.sku,
   MAX (b.descr) descr,
   stdcube = c.cubeuom3,
   sum(a.qty*b.[cube] ) Cubes,
   sum(a.qty) as each
   from lotxlocxid a(nolock), sku b(nolock), pack c(nolock), storer d(nolock)
   where a.sku = b.sku
   and a.storerkey = b.storerkey
   and b.PACKKey = c.PACKKey
   and a.storerkey = d.storerkey
   and c.casecnt <> 0
   and a.storerkey = @c_storerkey_Start
   and a.sku >= @c_sku_Start
   and a.sku <= @c_sku_End
   and b.itemclass >= @c_itemclass_Start
   and b.itemclass <= @c_itemclass_End

   group by a.storerkey, d.company, a.sku, c.cubeuom3
   order by a.storerkey, a.sku
END


GO