SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_receivinglabel_13                              */
/* Creation Date: 2014-11-14                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#324626 - FBMI Receiving Label with QR-Code              */
/*                                                                      */
/* Called By: r_dw_receivinglabel13                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.  Purposes                                 */
/* 20-Aug-2015 Audrey    1.1   SOS349728 - Bug fixed             (ang01)*/
/************************************************************************/

CREATE PROC [dbo].[isp_receivinglabel_13](
    @c_receiptkey         NVARCHAR(10)
   ,@c_receiptline_start  NVARCHAR(5)
   ,@c_receiptline_End    NVARCHAR(5)
 )
 AS
 BEGIN
  SET NOCOUNT ON
  SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE
           @c_RecLineNo    NVARCHAR(5),
           @c_QRCode       NVARCHAR(250)

     SELECT DISTINCT Receiptkey = RECEIPTDETAIL.ReceiptKey,
			            ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber,
                     Storerkey = RECEIPTDETAIL.StorerKey,
                     Sku = RECEIPTDETAIL.Sku,
                     ToLoc = RECEIPTDETAIL.ToLoc,
                     RecPutawayLoc = RECEIPTDETAIL.PutawayLoc,
                     Lottable01 = RECEIPTDETAIL.Lottable01,
                     Lottable02 = RECEIPTDETAIL.Lottable02,
                     Lottable03 = RECEIPTDETAIL.Lottable03,
                     Lottable04 = RECEIPTDETAIL.Lottable04,
                     Lottable05 = RECEIPTDETAIL.Lottable05,
                     RecQtyExpected = RECEIPTDETAIL.QtyExpected,
                     RecQtyRec = RECEIPTDETAIL.QtyReceived,
			            RecBeforeQty = RECEIPTDETAIL.BeforeReceivedQty,
			            ToID = RECEIPTDETAIL.TOID,
			            POKey = RECEIPTDETAIL.POKey,
                     SKU_DESCR = SKU.DESCR,
			            Lottable01Label = SKU.Lottable01Label,
			            Lottable02Label = SKU.Lottable02Label,
			            Lottable03Label = SKU.Lottable03Label,
			            Lottable04Label = SKU.Lottable04Label,
			            Lottable05Label = SKU.Lottable05Label,
                     CaseCnt = PACK.CaseCnt,
                     PQty = PACK.Qty,
                     P_Ti = PACK.PalletTI,
                     P_Hi = PACK.PalletHI,
			            PackDescr = PACK.PackDescr,
			            Loc_PutawayZone = Loc.Putawayzone,
			            Sku_Putawayzone = Sku.Putawayzone,
			            Loc_Facility = LOC.Facility,
			            Locb_PutawayZone = Loc_b.Putawayzone,
                     Sku_group = SKU.Skugroup,
                     RecUom = RECEIPTDETAIL.UOM,
                     RecExternReceiptKey = RECEIPTDETAIL.ExternReceiptKey,
                     Case_Qty = CASE WHEN PACK.Casecnt <> 0 THEN  convert(int,(receiptdetail.qtyreceived/pack.casecnt)) else 0 end ,
                     Each_Qty = CASE WHEN pack.casecnt > 1 and (receiptdetail.qtyreceived/pack.casecnt)-(convert(int,(receiptdetail.qtyreceived/pack.casecnt))) > 0
                                THEN convert(int,(receiptdetail.qtyreceived)) - (CASE WHEN PACK.Casecnt <> 0
                                THEN convert(int,(receiptdetail.qtyreceived/pack.casecnt)) else 0 end * pack.casecnt) --ang01
                    ELSE receiptdetail.qtyreceived END ,
                    QRCode = @c_QRCode
    INTO #RESULT
    FROM RECEIPTDETAIL (NOLOCK)
         JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
         LEFT JOIN LOC (NOLOCK) ON RECEIPTDETAIL.ToLoc = LOC.Loc
         JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey
			LEFT JOIN LOC LOC_b (NOLOCK) ON  RECEIPTDETAIL.PutawayLoc = LOC_b.Loc
   WHERE ( ( RECEIPTDETAIL.ReceiptKey = @c_receiptkey ) and
			  ( RECEIPTDETAIL.ReceiptlineNumber >= @c_receiptline_start ) AND
           ( RECEIPTDETAIL.ReceiptLineNumber <= @c_receiptline_end ) ) AND
			(RECEIPTDETAIL.TOID <> '' )


   DECLARE cur_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT receiptkey,receiptlinenumber
   FROM #RESULT
   Order By Receiptkey,Receiptlinenumber

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_Receiptkey,@c_RecLineNo
   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @c_QRCode = CAST(RecDet.Sku as nchar(25)) + CAST(RecDet.Lottable02 as nchar(30)) + CAST(RecDet.UOM as nchar(2))
                    + CAST(CONVERT(NVARCHAR(10),R.Case_Qty) as nchar(10)) + CAST(RIGHT(RecDet.Toid,8) as nchar(8))
                    --+ CAST(RecDet.Lottable03 as nchar(8)) --+ CAST(RecDet.Lottable04 as nchar(6))
                    --+ CAST(DAY(ISNULL(RecDet.Lottable03,'')) as nchar(2)) + CAST(MONTH(ISNULL(RecDet.Lottable03,'')) as nchar(2)) + CAST(YEAR(ISNULL(RecDet.Lottable03,'')) as nchar(4))
                    + REPLACE(CONVERT(NCHAR(10), RecDet.Lottable05, 103), '/', '')
                    -- + CAST((DATEPART(year,RecDet.Lottable04)-1900)*1000+DATEDIFF(day,RecDet.Lottable04,CAST("01-01-"+CAST(DATEPART(year,RecDet.Lottable04) AS CHAR(4)) AS SMALLDATETIME))+1 as nchar(6))
                    + cast(case when year(RecDet.Lottable04) <= 1999 then 0 else 1 end as varchar)
                    + substring(cast(year(RecDet.Lottable04) as varchar),3,2)
                    + REPLACE(STR(CAST(RecDet.Lottable04-DATEADD(yyyy,DATEDIFF(yyyy,0,RecDet.Lottable04),0) AS INT)+1,3), ' ','0')
                     FROM ReceiptDetail RecDet WITH (NOLOCK)
                     JOIN SKU S WITH (NOLOCK) ON S.Sku = RecDet.Sku
                     JOIN #Result R WITH (NOLOCK) ON R.receiptkey=RecDet.Receiptkey
                                                     and R.Receiptlinenumber = RecDet.Receiptlinenumber
                     AND RecDet.Receiptkey = @c_Receiptkey
                     AND RecDet.Receiptlinenumber= @c_RecLineNo

      UPDATE #RESULT
      SET QRCode = @c_QRCode
      WHERE Receiptkey = @c_Receiptkey
      AND Receiptlinenumber = @c_RecLineNo

      FETCH NEXT FROM cur_1 INTO @c_Receiptkey,@c_RecLineNo
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT *
   FROM #RESULT
   ORDER BY Receiptkey,Receiptlinenumber

   DROP TABLE #RESULT
 END

GRANT EXECUTE ON isp_receivinglabel_13 TO NSQL

GO