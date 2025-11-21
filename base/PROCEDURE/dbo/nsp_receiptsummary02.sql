SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_ReceiptSummary02                               */
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

CREATE PROC [dbo].[nsp_ReceiptSummary02] (
@c_receiptkey_start NVARCHAR(10),
@c_receiptkey_end   NVARCHAR(10),
@c_storerkey_start  NVARCHAR(18),
@c_storerkey_end    NVARCHAR(18),
@d_date_start	    datetime,
@d_date_end	    datetime
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT STORER.company,
   RECEIPT.receiptkey,
   RECEIPT.warehousereference,
   RECEIPT.pokey,
   RECEIPT.carrierkey,
   receiptdate = CONVERT(CHAR(10), RECEIPT.receiptdate, 103),
   totalqty = SUM(RECEIPTDETAIL.qtyreceived),
   totalpallets = 0
   INTO #RESULT
   FROM RECEIPT (NOLOCK) INNER JOIN RECEIPTDETAIL (NOLOCK)
   ON RECEIPT.receiptkey = RECEIPTDETAIL.receiptkey
   INNER JOIN STORER (NOLOCK)
   ON RECEIPT.storerkey = STORER.storerkey
   WHERE RECEIPT.receiptkey BETWEEN @c_receiptkey_start AND @c_receiptkey_end
   AND RECEIPT.storerkey BETWEEN @c_storerkey_start AND @c_storerkey_end
   AND RECEIPT.receiptdate >= @d_date_start
   AND RECEIPT.receiptdate <= @d_date_end
   GROUP BY STORER.company,
   RECEIPT.receiptkey,
   RECEIPT.warehousereference,
   RECEIPT.pokey,
   RECEIPT.carrierkey,
   CONVERT(CHAR(10), RECEIPT.receiptdate, 103)

   DECLARE @c_receiptkey NVARCHAR(10),
   @n_totalpallet int,
   @c_receiptlinenumber NVARCHAR(5),
   @c_sku NVARCHAR(20),
   @n_pallet int

   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT receiptkey FROM #RESULT

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_receiptkey
   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @n_totalpallet = 0
      DECLARE cur_2 CURSOR FAST_FORWARD READ_ONLY
      FOR
      SELECT receiptlinenumber, sku from RECEIPTDETAIL (NOLOCK) WHERE receiptkey = @c_receiptkey

      OPEN cur_2
      FETCH NEXT FROM cur_2 INTO @c_receiptlinenumber, @c_sku
      WHILE (@@fetch_status <> -1)
      BEGIN
         SELECT @n_pallet = PACK.pallet
         FROM SKU (NOLOCK) INNER JOIN PACK (NOLOCK)
         ON SKU.packkey = PACK.packkey
         WHERE sku = @c_sku

         IF @n_pallet <> 0
         BEGIN
            SELECT @n_totalpallet = @n_totalpallet + (qtyreceived / @n_pallet)
            FROM RECEIPTDETAIL (NOLOCK)
            WHERE receiptkey = @c_receiptkey
            AND receiptlinenumber = @c_receiptlinenumber
            AND sku = @c_sku
         END

         FETCH NEXT FROM cur_2 INTO @c_receiptlinenumber, @c_sku
      END
      CLOSE cur_2
      DEALLOCATE cur_2

      UPDATE #RESULT
      SET totalpallets = @n_totalpallet
      WHERE receiptkey = @c_receiptkey

      FETCH NEXT FROM cur_1 INTO @c_receiptkey
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT * FROM #RESULT
   DROP TABLE #RESULT
END

GO