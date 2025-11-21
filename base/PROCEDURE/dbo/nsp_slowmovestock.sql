SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_slowmovestock                                  */
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

CREATE PROC [dbo].[nsp_slowmovestock] (
@StorerMin      NVARCHAR(15),
@StorerMax      NVARCHAR(15),
@SkuGroupMin    NVARCHAR(10),
@SkuGroupMax    NVARCHAR(10),
@SkuMin         NVARCHAR(20),
@SkuMax         NVARCHAR(20),
@Daycheck      NVARCHAR(3)
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT @StorerMin,
      @StorerMax,
      @SkugroupMin,
      @SkugroupMax,
      @SkuMin,
      @SkuMax,
      @Daycheck
   END
   SELECT storerkey, sku, editdate
   INTO #skuslowmove
   FROM itrn (nolock)
   WHERE 1 = 2

   DECLARE @c_storerkey NVARCHAR(15), @c_skunomove NVARCHAR(20), @d_lastdate datetime
   DECLARE @c_storerskunomove NVARCHAR(35)

   SELECT @c_storerskunomove = ''
   WHILE (1 = 1)
   BEGIN
      SET ROWCOUNT 1
      SELECT @c_storerskunomove = dbo.fnc_LTrim(dbo.fnc_RTrim(i.storerkey)) + dbo.fnc_LTrim(dbo.fnc_RTrim(i.sku))
      , @c_storerkey = i.storerkey
      , @c_skunomove = i.sku
      , @d_lastdate = i.editdate
      FROM itrn i (nolock), sku s (nolock)
      WHERE i.storerkey = s.storerkey
      AND   i.sku = s.sku
      AND  (dbo.fnc_LTrim(dbo.fnc_RTrim(i.storerkey)) + dbo.fnc_LTrim(dbo.fnc_RTrim(i.sku))) > @c_storerskunomove
      AND   datediff(dd, i.editdate, getdate()) > convert(int,@daycheck)
      AND   i.trantype = 'WD'
      AND   i.storerkey BETWEEN @storermin   AND @storermax
      AND   s.skugroup  BETWEEN @skugroupmin AND @skugroupmax
      AND   i.sku       BETWEEN @skumin      AND @skumax
      ORDER BY i.storerkey, i.sku, i.editdate desc

      IF @@ROWCOUNT = 0
      BEGIN
         SET ROWCOUNT 0
         BREAK
      END

      INSERT #skuslowmove values (@c_storerkey, @c_skunomove, @d_lastdate)
   END
   IF @b_debug = 0
   BEGIN
      SELECT s.storerkey
      , b.company
      , a.skugroup
      , (select description from codelkup (nolock) where listname = 'SKUGROUP' and code = a.skugroup)
      , s.sku
      , a.descr
      , s.editdate
      , l.lot
      , l.qty
      , a.packkey
      , (select packuom3 from pack p (nolock) where a.packkey = p.packkey)
      FROM #skuslowmove s (nolock), sku a (nolock), storer b (nolock), lot l (nolock)
      WHERE s.storerkey = b.storerkey
      AND       s.storerkey = a.storerkey
      AND       s.sku = a.sku
      AND       s.storerkey = l.storerkey
      AND       s.sku = l.sku
      AND       s.sku not in (select distinct i.sku from inventoryhold i (nolock) where i.storerkey = s.storerkey and i.status = '1')
      AND       l.qty <> 0
   END
END

GO