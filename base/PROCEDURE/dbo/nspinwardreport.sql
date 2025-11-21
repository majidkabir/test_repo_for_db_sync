SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspInwardReport                                    */
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
/************************************************************************/

CREATE PROCEDURE [dbo].[nspInwardReport](
@c_StorerMin    NVARCHAR(10),
@c_StorerMax    NVARCHAR(10),
@c_ReceiptDateMin	datetime,
@c_ReceiptDateMax	datetime,
@c_SKUMin       NVARCHAR(20),
@c_SKUMax       NVARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_receiptkey  NVARCHAR(10),
   @c_sku	 NVARCHAR(20),
   @n_qty		int,
   @d_receiptdate	datetime,
   @c_storerkey	 NVARCHAR(18),
   @c_carriername NVARCHAR(30),
   @c_containerkey NVARCHAR(18),
   @c_vehiclenumber NVARCHAR(18),
   @d_podate		datetime,
   @c_pokey	 NVARCHAR(10),
   @c_descr	 NVARCHAR(60),
   @c_notes	 NVARCHAR(244),
   @c_editwho	 NVARCHAR(18),
   @d_receiptdatemin	datetime,
   @d_receiptdatemax	datetime

   -- convert dates
   SELECT @d_receiptdatemin = @c_ReceiptDateMin
   SELECT @d_receiptdatemax = @c_ReceiptDateMax

   -- create temp table to hold result set
   SELECT RECEIPT.receiptdate,
   RECEIPT.storerkey,
   carriername = space(30),
   containerkey = space(18),
   vehiclenumber = space(18),
   PO.podate,
   pokey = space(10),
   SKU.descr,
   RECEIPTDETAIL.qtyreceived,
   RECEIPTDETAIL.editwho,
   notes = space(244),
   receiptkey = space(10),
   sku = space(20)
   INTO #TEMP
   FROM PO (NOLOCK),
   RECEIPT (NOLOCK),
   RECEIPTDETAIL (NOLOCK),
   SKU (NOLOCK)
   WHERE 1 = 2

   -- create cursor to process data
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT A.receiptkey,
   A.sku,
   qty = SUM(A.qtyreceived)
   FROM RECEIPTDETAIL A (NOLOCK), RECEIPT B (NOLOCK)
   WHERE A.receiptkey = B.receiptkey
   AND B.storerkey   BETWEEN @c_StorerMin      AND @c_StorerMax
   AND A.sku         BETWEEN @c_SKUMin         AND @c_SKUMax
   AND B.receiptdate >= CONVERT(datetime, @d_ReceiptDateMin)
   AND B.receiptdate < DATEADD(day, 1, CONVERT(datetime, @d_ReceiptDateMax))
   AND A.qtyreceived > 0
   GROUP BY A.receiptkey, A.sku

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_receiptkey, @c_sku, @n_qty
   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @d_receiptdate = A.receiptdate,
      @c_storerkey = A.storerkey,
      @c_carriername = A.carriername,
      @c_containerkey = A.containerkey,
      @c_vehiclenumber = A.vehiclenumber,
      @c_pokey = A.pokey,
      @c_descr = C.descr,
      @c_notes = A.notes,
      @c_editwho = B.editwho
      FROM  RECEIPT A (NOLOCK),
      RECEIPTDETAIL B (NOLOCK),
      SKU C (NOLOCK)
      WHERE A.receiptkey = B.receiptkey
      AND B.sku = C.sku
      AND A.receiptkey = @c_receiptkey
      AND B.sku = @c_sku

      SELECT @d_podate = podate
      FROM PO (NOLOCK)
      WHERE pokey = @c_pokey

      -- populate temp table
      INSERT INTO #TEMP VALUES(@d_receiptdate, @c_storerkey, @c_carriername, @c_containerkey, @c_vehiclenumber, @d_podate,
      @c_pokey, @c_descr, @n_qty, @c_editwho, @c_notes, @c_receiptkey, @c_sku)

      FETCH NEXT FROM cur_1 INTO @c_receiptkey, @c_sku, @n_qty
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   -- return result set
   SELECT receiptdate,
   storerkey,
   carriername,
   containerkey,
   vehiclenumber,
   podate,
   pokey,
   descr,
   qtyreceived,
   editwho,
   notes,
   sku,
   receiptkey
   FROM #TEMP
   ORDER BY receiptdate, receiptkey, sku
   DROP TABLE #TEMP
END


GO