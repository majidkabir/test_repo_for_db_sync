SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspSummaryReport                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: r_stock_movement_summary (INV93)                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.  Purposes                                 */
/* 01-Jun-2009  NJOW     1.1   Fix the missing sku parameters error in  */ 
/*                             Datawindow. Add sku param                */
/************************************************************************/

/****** Object:  Stored Procedure dbo.nspSummaryReport    Script Date: 3/11/99 6:24:26 PM ******/
CREATE PROC [dbo].[nspSummaryReport](
@c_storerstart NVARCHAR(15),
@c_storerend NVARCHAR(15),
@c_skustart NVARCHAR(20),
@c_skuend NVARCHAR(20),
@d_datestart	datetime,
@d_dateend	datetime
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @d_date_start	datetime,
   @d_date_end	datetime,
   @c_sku	 NVARCHAR(20),
   @c_storerkey NVARCHAR(15),
   @c_contact NVARCHAR(30),
   @c_lot	 NVARCHAR(10),
   @c_uom	 NVARCHAR(10),
   @n_qtydp	decimal (26,8),
   @n_qtyaj	decimal (26,8),
   @n_qtywd	decimal (26,8),
   @n_qtyopen	decimal (26,8),
   @n_qtyclose	decimal (26,8),
   @c_logical NVARCHAR(6),
   @c_mfglot NVARCHAR(18),
   @d_expiry	datetime,
   @c_company NVARCHAR(60)
   SELECT  @d_date_end   =  DATEADD(day, 1, CONVERT(datetime,convert(char(20),@d_dateend,100)))
   -- SELECT  @d_date_end   =  CONVERT(datetime,convert(char(20),@d_dateend,100))
   SELECT  @d_date_start = CONVERT(datetime, CONVERT(char(20), @d_datestart,100))
   /*Create Temp Result table */
   SELECT ITRN.storerkey storerkey,
   company = space(60),
   ITRN.sku sku,
   uom = space(2),
   CONVERT(decimal (26,8),ITRN.qty) qtyopen,
   CONVERT(decimal (26,8),ITRN.qty) qtyreceive,
   CONVERT(decimal (26,8),ITRN.qty) qtyadjusted,
   CONVERT(decimal (26,8),ITRN.qty) qtyship,
   CONVERT(decimal (26,8),ITRN.qty) qtyclose,
   logical = space(6),
   mfglot = space(18),
   expiry = GETDATE(),
   asof = GETDATE()
   INTO #RESULT from ITRN (NOLOCK) where 1 = 2
   DECLARE CUR_1 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT LOT.storerkey,
   LOT.sku,
   LOT.lot
   FROM LOT (NOLOCK), ITRN (NOLOCK), SKU (NOLOCK)
   WHERE LOT.storerkey = ITRN.storerkey
   AND LOT.sku = ITRN.sku
   AND LOT.sku = SKU.sku
   AND LOT.lot = ITRN.lot
   AND LOT.storerkey BETWEEN @c_storerstart AND @c_storerend
   AND SKU.Sku BETWEEN @c_skustart AND @C_skuend
   -- AND ITRN.editdate < @d_date_end
   -- AND ITRN.editdate >= @d_date_start
   AND ITRN.trantype in ('DP','AJ','WD')
   AND ITRN.qty <> 0
   AND SKU.active <> '0'
   GROUP BY LOT.storerkey, LOT.lot, LOT.sku
   ORDER BY LOT.storerkey,LOT.sku
   OPEN CUR_1
   FETCH NEXT FROM CUR_1
   INTO @c_storerkey,@c_sku,@c_lot
   WHILE (@@FETCH_STATUS = 0)
   BEGIN  /* fetch loop */
      SELECT @n_qtyopen = 0, @n_qtydp = 0, @n_qtywd = 0, @n_qtyclose = 0
      SELECT @c_uom = packuom3
      FROM SKU (NOLOCK),PACK (NOLOCK)
      WHERE SKU.sku = @c_sku
      AND SKU.packkey = PACK.packkey
      /* Opening Stock Balance - Before start date */
      SELECT @n_qtyopen = SUM(ITRN.qty)
      FROM ITRN (NOLOCK)
      WHERE (ITRN.storerkey = @c_storerkey and
      ITRN.trantype in ('DP','AJ','WD') and
      ITRN.sku = @c_sku and
      ITRN.lot = @c_lot and
      ITRN.editdate < @d_date_start and
      ITRN.qty <> 0)
      /* Qty Received - Between specified dates */
      SELECT @n_qtydp = SUM(ITRN.qty)
      FROM ITRN (NOLOCK)
      WHERE (ITRN.storerkey = @c_storerkey and
      ITRN.trantype = 'DP' and
      ITRN.sku = @c_sku and
      ITRN.lot = @c_lot and
      ITRN.editdate < @d_date_end and
      ITRN.editdate >= @d_date_start and
      ITRN.qty <> 0)
      /* Qty Adjusted - Between specified dates */
      SELECT @n_qtyaj = SUM(ITRN.qty)
      FROM ITRN (NOLOCK)
      WHERE (ITRN.storerkey = @c_storerkey and
      ITRN.trantype = 'AJ' and
      ITRN.sku = @c_sku and
      ITRN.lot = @c_lot and
      ITRN.editdate < @d_date_end and
      ITRN.editdate >= @d_date_start and
      ITRN.qty <> 0)
      /* Qty Shipped - Between specified dates */
      SELECT @n_qtywd = ABS(SUM(ITRN.qty))
      FROM ITRN (NOLOCK)
      WHERE (ITRN.storerkey = @c_storerkey and
      ITRN.trantype = 'WD' and
      ITRN.sku = @c_sku and
      ITRN.lot = @c_lot and
      ITRN.editdate < @d_date_end and
      ITRN.editdate >= @d_date_start and
      ITRN.qty <> 0)
      IF @n_qtywd = 0
      BEGIN
         SELECT @n_qtywd = qtyallocated
         FROM LOT
         WHERE storerkey = @c_storerkey
         AND sku = @c_sku
         AND lot = @c_lot
      END
      IF @n_qtyopen IS NULL SELECT @n_qtyopen = 0
      IF @n_qtydp IS NULL SELECT @n_qtydp = 0
      IF @n_qtywd IS NULL SELECT @n_qtywd = 0
      IF @n_qtyaj IS NULL SELECT @n_qtyaj = 0
      SELECT @n_qtyclose = @n_qtyopen + @n_qtydp + @n_qtyaj - @n_qtywd

      SELECT @c_mfglot = lottable02, @c_logical = lottable03, @d_expiry = ISNULL(lottable04,Convert(datetime,'1900-01-01'))
      FROM LOTATTRIBUTE
      WHERE lot = @c_lot
      SELECT @c_company = company
      FROM STORER
      WHERE storerkey = @c_storerkey
      INSERT #RESULT
      VALUES (@c_storerkey,@c_company,@c_sku,@c_uom,@n_qtyopen,@n_qtydp,@n_qtyaj,
      @n_qtywd,@n_qtyclose,@c_logical,@c_mfglot,@d_expiry,@d_date_start)
      FETCH NEXT FROM CUR_1
      INTO @c_storerkey,@c_sku,@c_lot
   END  /* cursor loop */
   CLOSE      CUR_1
   DEALLOCATE CUR_1
   /* clean result table */
   DELETE #RESULT
   WHERE qtyopen = 0 AND qtyreceive = 0 AND qtyadjusted = 0
   AND qtyship = 0 AND qtyclose = 0
   UPDATE #RESULT
   SET expiry = Convert(datetime,'1900-01-01')
   WHERE mfglot = ''
   /* Return Result set */
   SELECT #RESULT.storerkey,
   #RESULT.company,
   #RESULT.sku,
   SKU.Descr,
   #RESULT.uom,
   qtyopen = CONVERT(decimal (26,8), SUM(#RESULT.qtyopen)),
   qtyreceive = CONVERT(decimal (26,8), SUM(#RESULT.qtyreceive)),
   qtyadjusted = CONVERT(decimal (26,8), SUM(#RESULT.qtyadjusted)),
   qtyship = CONVERT(decimal (26,8), SUM(#RESULT.qtyship)),
   qtyclose = CONVERT(decimal (26,8), SUM(#RESULT.qtyclose)),
   #RESULT.logical,
   #RESULT.mfglot,
   #RESULT.expiry,
   #RESULT.asof
   FROM   #RESULT, SKU (NOLOCK)
   WHERE  #RESULT.sku = SKU.sku and
   #RESULT.storerkey = SKU.storerkey
   GROUP BY #RESULT.storerkey,
   #RESULT.company,
   #RESULT.sku,
   SKU.Descr,
   #RESULT.uom,
   #RESULT.logical,
   #RESULT.mfglot,
   #RESULT.expiry,
   #RESULT.asof
   ORDER BY #RESULT.storerkey, #RESULT.sku
   DROP TABLE #RESULT
END /* main procedure */

GO