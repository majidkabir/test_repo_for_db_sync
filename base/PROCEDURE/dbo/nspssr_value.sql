SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspSSR_value                                       */
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

/****** Object:  Stored Procedure dbo.nspSSR_value    Script Date: 3/11/99 6:24:26 PM ******/
CREATE PROC [dbo].[nspSSR_value](
@c_storerstart NVARCHAR(15),
@c_storerend NVARCHAR(15),
@c_whse	 NVARCHAR(6)
)
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT SKU.storerkey,
   STORER.company,
   LOT.sku,
   SKU.descr,
   PACK.packuom3,
   SKU.skugroup,
   qty = SUM(LOT.qty - LOT.qtyallocated),
   SKU.price,
   total_price = SUM((LOT.qty - LOT.qtyallocated) * SKU.price),
   total_cost = SUM((LOT.qty - LOT.qtyallocated) * SKU.cost)
   FROM LOT, LOTATTRIBUTE, SKU, STORER, PACK
   WHERE LOT.lot = LOTATTRIBUTE.lot
   AND LOT.sku = SKU.sku
   AND LOTATTRIBUTE.lottable03 = @c_whse
   AND LOT.qty <> 0
   AND SKU.storerkey = STORER.storerkey
   AND SKU.packkey = PACK.packkey
   AND LOT.storerkey >= @c_storerstart
   AND LOT.storerkey <= @c_storerend
   GROUP BY SKU.storerkey, STORER.company, LOT.sku, SKU.descr, PACK.packuom3, SKU.skugroup, SKU.price
   ORDER BY LOT.sku
END	-- main procedure
-- GRANT  EXECUTE  ON dbo.nspSSR_value TO NSQL
-- GO

GO