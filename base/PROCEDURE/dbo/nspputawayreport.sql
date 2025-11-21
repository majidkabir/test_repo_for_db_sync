SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPutawayReport                                   */
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
/* Date         Author   ver  Purposes                                  */
/* 14-09-2009   TLTING   1.1  ID field length   (tlting01)              */
/* 02-Jun-2014  TKLIM    1.1   Added Lottables 06-15                    */
/************************************************************************/

CREATE PROC [dbo].[nspPutawayReport] (
   @c_storer_start   NVARCHAR(15),
   @c_storer_end     NVARCHAR(15),
   @c_sku_start      NVARCHAR(20),
   @c_sku_end        NVARCHAR(20),
   @d_date_start     DATETIME,
   @d_date_end       DATETIME
)
AS
BEGIN -- main
    SET NOCOUNT ON
    SET ANSI_NULLS OFF 
    SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_storerkey             NVARCHAR(15),
            @c_sku                  NVARCHAR(20),
            @c_packkey              NVARCHAR(10),
            @n_qty                  int,
            @c_uom                  NVARCHAR(10),
            @c_lot                  NVARCHAR(10),
            @c_fromloc              NVARCHAR(10),
            @c_toloc                NVARCHAR(10),
            @c_fromid               NVARCHAR(18),      -- tlting01
            @c_toid                 NVARCHAR(18),      -- tlting01
            @c_sourcekey            NVARCHAR(20),
            @c_receiptkey           NVARCHAR(20),
            @c_Lottable01           NVARCHAR(18),
            @c_Lottable02           NVARCHAR(18),
            @c_Lottable03           NVARCHAR(18),
            @d_Lottable04           DATETIME,
            @d_Lottable05           DATETIME,
            @c_Lottable06           NVARCHAR(30),
            @c_Lottable07           NVARCHAR(30),
            @c_Lottable08           NVARCHAR(30),
            @c_Lottable09           NVARCHAR(30),
            @c_Lottable10           NVARCHAR(30),
            @c_Lottable11           NVARCHAR(30),
            @c_Lottable12           NVARCHAR(30),
            @d_Lottable13           DATETIME,
            @d_Lottable14           DATETIME,
            @d_Lottable15           DATETIME,
            @c_descr                NVARCHAR(65),
            @c_susr3                NVARCHAR(18),
            @n_casecnt              int,
            @c_pokey                NVARCHAR(10),
            @n_qtyexpected          int,
            @c_warehousereference   NVARCHAR(18),
            @c_carrierreference     NVARCHAR(18),
            @c_company              NVARCHAR(60),
            @c_notes                NVARCHAR(250)


   SELECT RECEIPT.receiptkey,
         RECEIPTDETAIL.pokey,
         RECEIPTDETAIL.sku,
         descr,
         uom,
         Lottable01,
         Lottable04,
         Lottable05,
         company,
         RECEIPTDETAIL.packkey,
         Sku.susr3,
         qtyexpected,
         qtyreceived,
         RECEIPTDETAIL.putawayloc,
         toid,
         casecnt,
         warehousereference,
         carrierreference,
         notes,
         Lottable02,
         Lottable03,
         Lottable06,
         Lottable07,
         Lottable08,
         Lottable09,
         Lottable10,
         Lottable11,
         Lottable12,
         Lottable13,
         Lottable14,
         Lottable15
   INTO #RESULT
   FROM RECEIPT, RECEIPTDETAIL, SKU, STORER
   WHERE 1 = 2


   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT ITRN.storerkey, ITRN.sku, ITRN.packkey, qty, lot, fromloc, toloc, fromid, toid, sourcekey, susr3
   FROM ITRN (NOLOCK) INNER JOIN SKU (NOLOCK)
   ON ITRN.sku = SKU.sku
   WHERE trantype = 'MV'
   AND sourcetype = 'nspRFPA02'
   AND ITRN.storerkey BETWEEN @c_storer_start AND @c_storer_end
   AND SKU.sku BETWEEN @c_sku_start AND @c_sku_end
   AND ITRN.adddate BETWEEN @d_date_start AND @d_date_end


   OPEN cur_1

   FETCH NEXT FROM cur_1 INTO @c_storerkey, @c_sku, @c_packkey, @n_qty, @c_uom, @c_lot, @c_fromloc, 
                              @c_toloc, @c_fromid, @c_toid, @c_sourcekey, @c_susr3

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN -- cur_1
      -- get deposit transaction from itrn
      SELECT @c_receiptkey = sourcekey,
            @c_Lottable01 = Lottable01,
            @c_Lottable02 = Lottable02,
            @c_Lottable03 = Lottable03,
            @d_Lottable04 = Lottable04,
            @d_Lottable05 = Lottable05,
            @c_Lottable06 = Lottable06,
            @c_Lottable07 = Lottable07,
            @c_Lottable08 = Lottable08,
            @c_Lottable09 = Lottable09,
            @c_Lottable10 = Lottable10,
            @c_Lottable11 = Lottable11,
            @c_Lottable12 = Lottable12,
            @d_Lottable13 = Lottable13,
            @d_Lottable14 = Lottable14,
            @d_Lottable15 = Lottable15,
            @n_casecnt = PACK.casecnt,
            @c_descr = descr
      FROM ITRN (NOLOCK) INNER JOIN PACK (NOLOCK)
      ON ITRN.packkey = PACK.packkey
      INNER JOIN SKU (NOLOCK)
      ON ITRN.SKU = SKU.sku
      WHERE trantype = 'DP'
      AND sourcetype LIKE 'ntrReceiptDetail%'
      AND toloc = 'STAGE'
      AND lot = @c_lot
      AND toid = @c_fromid
      AND ITRN.sku = @c_sku
      -- get receipt information

      SELECT @c_pokey = RECEIPT.pokey,
            @n_qtyexpected = qtyexpected,
            @c_warehousereference = warehousereference,
            @c_carrierreference = carrierreference,
            @c_company = company,
            @c_notes = notes
      FROM RECEIPT (NOLOCK) INNER JOIN RECEIPTDETAIL (NOLOCK)
      ON RECEIPT.receiptkey = RECEIPTDETAIL.receiptkey
      INNER JOIN STORER (NOLOCK)
      ON RECEIPT.storerkey = STORER.storerkey
      WHERE RECEIPT.receiptkey + RECEIPTDETAIL.receiptlinenumber = @c_receiptkey

      INSERT #RESULT 
      VALUES (LEFT(@c_receiptkey,10), @c_pokey, @c_sku, @c_descr, @c_uom, 
               @c_Lottable01, @d_Lottable04, @d_Lottable05,
               @c_susr3, @n_qtyexpected, @n_qty, @c_toloc, @c_toid, @n_casecnt, @c_warehousereference,
               @c_carrierreference, @c_notes, @c_Lottable02, @c_Lottable03,
               @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
               @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15)

      FETCH NEXT FROM cur_1 INTO @c_storerkey, @c_sku, @c_packkey, @n_qty, @c_uom, @c_lot, @c_fromloc, 
                                 @c_toloc, @c_fromid, @c_toid, @c_sourcekey, @c_susr3
   END -- cur_1
   CLOSE cur_1
   DEALLOCATE cur_1
   SELECT * FROM #RESULT
   DROP TABLE #RESULT
END -- main

GO