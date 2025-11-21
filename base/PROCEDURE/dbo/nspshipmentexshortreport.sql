SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspShipmentExShortReport                           */
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

CREATE PROCEDURE [dbo].[nspShipmentExShortReport] (
@c_StorerMin    NVARCHAR(10),
@c_StorerMax    NVARCHAR(10),
@c_ReceiptDateMin NVARCHAR(10),
@c_ReceiptDateMax NVARCHAR(10),
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
   @n_qtyreceived	int,
   @n_qtyexpected	int,
   @n_qtydamaged		int,
   @d_receiptdate	datetime,
   -- @d_podate		datetime,
   @c_asn NVARCHAR(10),
   @c_pokey	 NVARCHAR(10),
   @c_descr	 NVARCHAR(60),
   @d_receiptdatemin	datetime,
   @d_receiptdatemax	datetime

   -- convert dates
   SELECT @d_receiptdatemin = CONVERT(datetime, @c_ReceiptDateMin)
   SELECT @d_receiptdatemax = CONVERT(datetime, @c_ReceiptDateMax)

   -- create temp table to hold result set
   SELECT RECEIPT.PoKey,
   RECEIPT.ReceiptKey,
   RECEIPT.ReceiptDate,
   RECEIPTDETAIL.Sku,
   SKU.DESCR,
   RECEIPTDETAIL.QtyExpected,
   RECEIPTDETAIL.QtyReceived,
   QtyDamaged = 0
   INTO #TEMP
   FROM PO (NOLOCK),
   RECEIPT (NOLOCK),
   RECEIPTDETAIL (NOLOCK),
   SKU (NOLOCK)
   WHERE 1 = 2

   -- create cursor to process data
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT A.receiptkey, A.sku, qtyreceived = SUM(A.qtyreceived), qtyexpected = SUM(A.qtyexpected)
   FROM RECEIPTDETAIL A (NOLOCK) INNER JOIN RECEIPT B (NOLOCK)
   ON A.receiptkey = B.receiptkey
   WHERE A.storerkey BETWEEN @c_StorerMin AND @c_StorerMax
   AND A.sku BETWEEN @c_SKUMin AND @c_SKUMax
   AND B.receiptdate BETWEEN @d_ReceiptDateMin AND @d_ReceiptDateMax
   AND A.qtyreceived <> 0
   GROUP BY A.receiptkey, A.sku
   ORDER BY A.receiptkey

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_receiptkey, @c_sku, @n_qtyreceived, @n_qtyexpected
   WHILE (@@fetch_status <> -1)
   BEGIN
      --get PO data
      SELECT @c_pokey = pokey,
      @c_asn = ReceiptKey,
      @d_receiptdate = receiptdate
      FROM RECEIPT
      where receiptkey = @c_receiptkey

      -- get item descr
      SELECT @c_descr = descr
      FROM SKU
      WHERE sku = @c_sku

      -- check if there is damaged qty
      SELECT @n_qtydamaged = COALESCE(SUM(qtyreceived), 0)
      FROM RECEIPTDETAIL A INNER JOIN LOC B
      ON A.toloc = B.loc
      AND B.locationflag = 'DAMAGE'
      AND A.receiptkey = @c_receiptkey
      AND A.sku = @c_sku

      -- populate result table
      INSERT INTO #TEMP
      VALUES (@c_pokey, @c_asn, @d_receiptdate, @c_sku, @c_descr, @n_qtyreceived, @n_qtyexpected, @n_qtydamaged)

      FETCH NEXT FROM cur_1 INTO @c_receiptkey, @c_sku, @n_qtyreceived, @n_qtyexpected
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   -- return result set
   SELECT * FROM #TEMP
   DROP TABLE #TEMP
END

GO