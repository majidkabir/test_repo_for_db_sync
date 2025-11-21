SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_receivinglabel_16                              */
/* Creation Date: 2016-07-14                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#373381 - TH-MFG New Receiving Label 4x2                 */
/*                                                                      */
/* Called By: r_dw_receivinglabel16                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.  Purposes                                 */
/* 21-Sep-2016 MTTey     1.0   IN00153719 UOM QTY DECIMAL TO FLOAT      */
/*                             CONVERSION ERROR      --(MT01)           */
/* 23-Sep-2016 NJOW01    1.1   WMS-331 Add sku parameter                */
/* 21-Feb-2017 CSCHONG   1.2   WMS-1126 Add new field (CS01)            */
/* 13-Oct-2020 CSCHONG   1.3   WMS-15418 revised sorting (CS02)         */
/************************************************************************/

CREATE PROC [dbo].[isp_receivinglabel_16_rdt](
    @c_receiptkey         NVARCHAR(10)
   ,@c_receiptline_start  NVARCHAR(5)
   ,@c_receiptline_End    NVARCHAR(5)
   ,@c_Sku                NVARCHAR(20) = '' --NJOW01   
 )
 AS
 BEGIN
  SET NOCOUNT ON
  SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE
           @c_RecLineNo      NVARCHAR(5),
           @c_Getreceiptkey  NVARCHAR(10),
           @c_skuGrp         NVARCHAR(10),
           @c_recUOM         NVARCHAR(10),
           @n_BfQtyRec       FLOAT,
           @n_QtyRecv        FLOAT,
           @n_qty            INT,--DECIMAL(8,1),
           @n_uomqty         FLOAT,--DECIMAL(8,1),
           @c_uom            NVARCHAR(10)

    --NJOW01
    IF ISNULL(@c_receiptline_start,'') = ''
       SET @c_receiptline_start = '0'

    IF ISNULL(@c_receiptline_End,'') = ''
       SET @c_receiptline_End = '99999'

      SET @c_uom = ''


       CREATE TABLE #TMP_Recv16
            (
               Receiptkey                NVARCHAR(20) DEFAULT ('')
            ,  receiptlinenumber         NVARCHAR(10) DEFAULT ('')
            ,  Storerkey                 NVARCHAR(20) DEFAULT ('')
            ,  sku                       NVARCHAR(20) DEFAULT ('')
            ,  rhudef04                  NVARCHAR(30) DEFAULT ('')
            ,  lottable02                NVARCHAR(18) DEFAULT ('')
            ,  lottable03                NVARCHAR(18) DEFAULT ('')
            ,  sku_descr                 NVARCHAR(60) DEFAULT ('')
            ,  company                   NVARCHAR(45) DEFAULT ('')
            ,  Sku_group                 NVARCHAR(20) DEFAULT ('')
            ,  recuom                    NVARCHAR(20) DEFAULT ('')
            ,  qty                       NVARCHAR(10) DEFAULT ('')
            ,  uomqty                    NVARCHAR(10) DEFAULT ('')
            ,  deliverydate              NVARCHAR(10) DEFAULT ('')
            ,  SUSR5                     NVARCHAR(18) DEFAULT ('')     --(CS01)
            )

     INSERT INTO #TMP_Recv16(
      Receiptkey,receiptlinenumber,Storerkey,sku,rhudef04,lottable02,lottable03,
      sku_descr,company,Sku_group,recuom,qty,uomqty,deliverydate,SUSR5                     --(CS01)
     )

     SELECT DISTINCT Receiptkey = RECEIPT.Receiptkey,
                     receiptlinenumber = RECEIPTDETAIL.receiptlinenumber,
                     Storerkey = RECEIPTDETAIL.StorerKey,
                     Sku = RTRIM(RECEIPTDETAIL.Sku),
                     RHUDEF04 = RECEIPTDETAIL.Userdefine04,
                     Lottable02 = RECEIPTDETAIL.Lottable02,
                     Lottable03 = RECEIPTDETAIL.Lottable03,
                     SKU_DESCR = RTRIM(SKU.DESCR),
                     company = ISNULL(STO.company,''),
                     Sku_group = SKU.Skugroup,
                     RecUom = RECEIPTDETAIL.UOM,
                     Qty  = '',
                     UOMQty = '',
                     deliverydate = CONVERT(NVARCHAR(10),RECEIPTDETAIL.UserDefine07,105),
                     SUSR5 = SKU.BUSR5                                                   --(CS01)
    FROM RECEIPT WITH (NOLOCK)
         JOIN RECEIPTDETAIL WITH (NOLOCK) ON RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
         JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
         LEFT JOIN Storer STO WITH (NOLOCK) ON STO.Storerkey = RECEIPTDETAIL.Userdefine04
   WHERE ( ( RECEIPTDETAIL.ReceiptKey = @c_receiptkey ) and
           ( RECEIPTDETAIL.ReceiptlineNumber >= @c_receiptline_start ) AND
           ( RECEIPTDETAIL.ReceiptLineNumber <= @c_receiptline_end ) AND
        ( RECEIPTDETAIL.Sku = CASE WHEN ISNULL(@c_Sku,'') <> '' THEN @c_Sku ELSE RECEIPTDETAIL.Sku END ) AND --NJOW01
        ( RECEIPTDETAIL.BeforeReceivedQty > 0 OR RECEIPTDETAIL.QtyReceived > 0))  --NJOW01           

   DECLARE cur_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT receiptkey,receiptlinenumber,Sku_group,RecUom
   FROM #TMP_Recv16
   Order By Receiptkey,Receiptlinenumber

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_Getreceiptkey,@c_RecLineNo,@c_skuGrp,@c_recUOM
   WHILE (@@fetch_status <> -1)
   BEGIN

         SET @n_qty=0
         SET @n_uomqty = 0

        SELECT @n_BfQtyRec = SUM(ISNULL(CAST(BeforeReceivedqty AS DECIMAL(8,1)),0)),
                 @n_QtyRecv = SUM(ISNULL(CAST(QtyReceived AS DECIMAL(8,1)),0))
         FROM RECEIPTDETAIL WITH (NOLOCK)
         WHERE Receiptkey = @c_Getreceiptkey
         AND Receiptlinenumber = @c_RecLineNo

       IF @c_skuGrp = 'WG' AND @c_recUOM in ('KG','KG.')
       BEGIN
         IF @n_BfQtyRec > 0
         BEGIN
            SET @n_qty = @n_BfQtyRec
         END
         ELSE
         BEGIN
            SET @n_qty = @n_QtyRecv
         END
       END
       ELSE
       BEGIN
         IF @n_BfQtyRec > 0
         BEGIN
            SET @n_qty = @n_BfQtyRec
         END
         ELSE
         BEGIN
            SET @n_qty = @n_QtyRecv
         END
       END

       IF @c_skuGrp = 'WG' AND @c_recUOM in ('G','Gram','Gram.','G.')
       BEGIN

         SET @c_uom = 'KG'

         IF @n_BfQtyRec > 0
         BEGIN
            SET @n_uomqty = @n_BfQtyRec / 1000
         END
         ELSE
         BEGIN
            SET @n_uomqty = @n_QtyRecv / 1000
         END

       END
       ELSE
       BEGIN

         SET @c_uom = @c_recUOM

         --BEGIN
            IF @n_BfQtyRec > 0
             BEGIN
               SET @n_uomqty = @n_BfQtyRec
             END
            ELSE
            BEGIN
               SET @n_uomqty = @n_QtyRecv 
            END
         END
                 
       UPDATE #TMP_Recv16
      SET qty = CONVERT(NVARCHAR(10),@n_qty)
      ,UOMqty = CONVERT(NVARCHAR(10),round(@n_uomqty,1))           --(MT01)
      ,recuom = @c_uom
      WHERE Receiptkey = @c_Receiptkey
      AND receiptlinenumber = @c_RecLineNo

   FETCH NEXT FROM cur_1 INTO @c_Getreceiptkey,@c_RecLineNo,@c_skuGrp,@c_recUOM
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT *
   FROM #TMP_Recv16
   ORDER BY Receiptkey,sku,qty,uomqty   --CS02

   DROP TABLE #TMP_Recv16
 END

GO