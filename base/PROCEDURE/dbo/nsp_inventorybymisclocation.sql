SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_InventoryBymiscLocation                        */
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
/* 2019-03-29   TLTING01 1.1  Bug fix                                   */ 
/************************************************************************/

CREATE PROC [dbo].[nsp_InventoryBymiscLocation] (
@c_location NVARCHAR(10)

)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_zone NVARCHAR(10),
   @c_loc NVARCHAR(10)

   SELECT putawayzone,
   loc,
   storerkey = space(18),
   sku = space(20),
   descr = space(60),
   lottable02 = space(18),
   lottable03 = space(18),
   lottable04 = space(10),
   qtyavail = 0,
   packkey = space(10),
   casecnt = 0,
   packuom3 = space(10),
   palletid = space(18)
   INTO #RESULT
   FROM LOC
   WHERE (1 = 2)

   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT putawayzone, loc
   FROM LOC
   WHERE loc =@c_location
   ORDER BY loc

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_zone, @c_loc
   WHILE (@@fetch_status <> -1)
   BEGIN
      INSERT #RESULT
      SELECT LOC.putawayzone,
      LOTxLOCxID.loc,
      LOTxLOCxID.storerkey,
      LOTxLOCxID.sku,
      SKU.descr,
      LOTATTRIBUTE.lottable02,
      LOTATTRIBUTE.lottable03,
      CONVERT(char(10), LOTATTRIBUTE.lottable04, 101),
      SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked),
      SKU.packkey,
      pack.casecnt,
      pack.packuom3,
      LOTxLOCxID.id
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKU (NOLOCK), LOTATTRIBUTE (NOLOCK), PACK (NOLOCK)
      WHERE LOTxLOCxID.loc = LOC.loc
      AND LOTxLOCxID.sku = SKU.sku
      AND LOTxLOCxID.lot = LOTATTRIBUTE.lot
      AND SKU.packkey = PACK.packkey
      AND LOTxLOCxID.loc = @c_loc
      GROUP BY LOC.putawayzone,
      LOTxLOCxID.loc,
      LOTxLOCxID.storerkey,
      LOTxLOCxID.sku,
      SKU.descr,
      LOTATTRIBUTE.lottable02,
      LOTATTRIBUTE.lottable03,
      CONVERT(char(10), LOTATTRIBUTE.lottable04, 101),
      SKU.packkey,
      pack.casecnt,
      pack.packuom3,
      LOTxLOCxID.id
      HAVING SUM(LOTxLOCxID.qty-LOTxLOCxID.qtyallocated-LOTxLOCxID.qtypicked) > 0
      ORDER BY LOTXLOCXID.Loc
      IF @@ROWCOUNT = 0
      INSERT #RESULT (putawayzone, loc, lottable04, qtyavail, casecnt)
      VALUES (@c_zone, @c_loc, '00/00/00', 0, 0)

      FETCH NEXT FROM cur_1 INTO @c_zone, @c_loc
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT * FROM #RESULT ORDER BY loc

   DROP TABLE #RESULT
END

GO