SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_receivinglabel_28                              */
/* Creation Date: 2023-05-29                                            */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#373381 - TH-MFG New Receiving Label 4x2                 */
/*                                                                      */
/* Called By: r_dw_receivinglabel28_rdt                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.  Purposes                                 */
/* 29-May-2023 Nicholas  1.0   copy from isp_receivinglabel_16_rdt      */
/************************************************************************/

CREATE PROC [dbo].[isp_receivinglabel_28_rdt](
    @c_receiptkey         NVARCHAR(10)
   ,@c_receiptline_start  NVARCHAR(5)
   ,@c_receiptline_End    NVARCHAR(5)
   ,@c_Sku                NVARCHAR(20) = ''
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
           @n_qty            INT,
           @n_uomqty         FLOAT,
           @c_uom            NVARCHAR(10),
           @c_FinalizeFlag  NVARCHAR(2)

    IF ISNULL(@c_receiptline_start,'') = ''
       SET @c_receiptline_start = '0'

    IF ISNULL(@c_receiptline_End,'') = ''
       SET @c_receiptline_End = @c_receiptline_start 

      SET @c_uom = ''

       CREATE TABLE #TMP_Recv28
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
            ,  SUSR5                     NVARCHAR(18) DEFAULT ('') 
            ,  FinalizeFlag             NVARCHAR(2)  DEFAULT ('') 
            ,  Busr1              NVARCHAR(60) DEFAULT ('') 
            ,  Style              NVARCHAR(40) DEFAULT ('') 
            ,  Size                  NVARCHAR(20) DEFAULT ('')
            ,  ToID                  NVARCHAR(36) DEFAULT ('')
            ,  PutawayLoc            NVARCHAR(20) DEFAULT ('')
            ,  PutawayZone           NVARCHAR(20) DEFAULT ('')
            ,  Appointment_no        NVARCHAR(20) DEFAULT ('')
            )

     INSERT INTO #TMP_Recv28(
      Receiptkey,receiptlinenumber,Storerkey,sku,rhudef04,lottable02,lottable03,
      sku_descr,company,Sku_group,recuom,qty,uomqty,deliverydate,SUSR5, FinalizeFlag, Busr1, Style, Size, ToID, PutawayLoc, PutawayZone, Appointment_no
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
                     Qty  = CASE WHEN receiptDetail.FinalizeFlag = 'N' THEN RECEIPTDETAIL.BeforeReceivedQty ELSE RECEIPTDETAIL.QtyReceived END,
                     UOMQty = '',
                     deliverydate = CONVERT(NVARCHAR(10),RECEIPTDETAIL.UserDefine07,105),
                     SUSR5 = SKU.BUSR5,
                     FinalizeFlag = receiptDetail.FinalizeFlag,
                     SKU.Busr1,
                     SKU.Style,
                     SKU.Size,
                     ReceiptDetail.ToID,
                     PutawayLoc = SKU.PutawayLoc,
                     PutawayZone = SKU.PutawayZone,
                     Receipt.Appointment_no
    FROM RECEIPT WITH (NOLOCK)
         JOIN RECEIPTDETAIL WITH (NOLOCK) ON RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
         JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
         LEFT JOIN Storer STO WITH (NOLOCK) ON STO.Storerkey = RECEIPTDETAIL.Userdefine04
   WHERE ( ( RECEIPTDETAIL.ReceiptKey = @c_receiptkey ) and
           ( RECEIPTDETAIL.ReceiptlineNumber >= @c_receiptline_start ) AND
           ( RECEIPTDETAIL.ReceiptLineNumber <= @c_receiptline_end ) AND
        ( RECEIPTDETAIL.Sku = CASE WHEN ISNULL(@c_Sku,'') <> '' THEN @c_Sku ELSE RECEIPTDETAIL.Sku END ) AND 
        ( RECEIPTDETAIL.BeforeReceivedQty > 0 OR RECEIPTDETAIL.QtyReceived > 0))     

   SELECT *
   FROM #TMP_Recv28
   ORDER BY Receiptkey,sku,qty,uomqty

   DROP TABLE #TMP_Recv28
 END

GO