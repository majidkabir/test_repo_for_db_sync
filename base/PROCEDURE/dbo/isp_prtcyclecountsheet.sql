SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_PrtCycleCountSheet] (
@c_StockTakeKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SELECT CCDETAIL.ccsheetno,
      CCDETAIL.lot,
      CCDETAIL.loc,
      CCDETAIL.id,
      CCDETAIL.storerkey,
      CCDETAIL.sku,
      SKU.descr,
      CCDETAIL.lottable01,
      CCDETAIL.lottable02,
      CCDETAIL.lottable03,
      CCDETAIL.lottable04,
      CCDETAIL.lottable05,
		CCDETAIL.lottable06,		--CS01
      CCDETAIL.lottable07,		--CS01
      CCDETAIL.lottable08,		--CS01
		CCDETAIL.lottable09,		--CS01
      CCDETAIL.lottable10,		--CS01
      CCDETAIL.lottable11,		--CS01
		CCDETAIL.lottable12,		--CS01
		CCDETAIL.lottable13,		--CS01
      CCDETAIL.lottable14,		--CS01
      CCDETAIL.lottable15,		--CS01
      CCDETAIL.qty,
      PACK.packuom3,
      LOC.putawayzone,
      LOC.loclevel,
      LOC.locAisle,
      LOC.facility
   FROM CCDETAIL (NOLOCK),
      SKU (NOLOCK),
      PACK (NOLOCK),
      LOC (NOLOCK)
   WHERE CCDETAIL.CCKEY = @c_StockTakeKey
   AND   CCDETAIL.LOC = LOC.LOC
   AND   CCDETAIL.StorerKey = SKU.StorerKey
   AND   CCDETAIL.SKU = SKU.SKU
   AND   SKU.PackKey = PACK.PackKey
   UNION
   SELECT CCDETAIL.ccsheetno,
      CCDETAIL.lot,
      CCDETAIL.loc,
      CCDETAIL.id,
      CCDETAIL.storerkey,
      CCDETAIL.sku,
      '',
      CCDETAIL.lottable01,
      CCDETAIL.lottable02,
      CCDETAIL.lottable03,
      CCDETAIL.lottable04,
      CCDETAIL.lottable05,
		CCDETAIL.lottable06,		--CS01
      CCDETAIL.lottable07,		--CS01
      CCDETAIL.lottable08,		--CS01
		CCDETAIL.lottable09,		--CS01
      CCDETAIL.lottable10,		--CS01
      CCDETAIL.lottable11,		--CS01
		CCDETAIL.lottable12,		--CS01
		CCDETAIL.lottable13,		--CS01
      CCDETAIL.lottable14,		--CS01
      CCDETAIL.lottable15,		--CS01
      CCDETAIL.qty,
      '',
      LOC.putawayzone,
      LOC.loclevel,
      LOC.locAisle,
      LOC.facility
   FROM CCDETAIL (NOLOCK),  LOC (NOLOCK)
   WHERE CCDETAIL.CCKEY = @c_StockTakeKey
   AND   CCDETAIL.LOC = LOC.LOC
   AND   CCDETAIL.SKU = ''
   ORDER BY CCDETAIL.ccsheetno, LOC.locAisle, LOC.loclevel

END


GO