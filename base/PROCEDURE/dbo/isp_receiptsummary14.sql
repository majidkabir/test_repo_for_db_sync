SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ReceiptSummary14                                    */
/* Creation Date: 06-Mar-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-8229 - MY - Levi's B2B GR Slip Report                   */
/*        :                                                             */
/* Called By:  r_dw_receipt_summary14                                   */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ReceiptSummary14]  
      @c_Receiptkey   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SELECT Receipt.Facility
          ,@c_Receiptkey AS ReceiptKey
          ,Receipt.FinalizeDate
          ,Receipt.IncoTerms
          ,Receipt.UserDefine01
          ,Receipt.UserDefine02
          ,Receipt.ExternReceiptKey
          ,ReceiptDetail.ExternLineNo
          ,ReceiptDetail.SKU
          ,SKU.DESCR
          ,SKU.Style
          ,SKU.Size
          ,ReceiptDetail.UserDefine01
          ,SUM(ReceiptDetail.QtyReceived)
          ,ReceiptDetail.UserDefine02 
   FROM RECEIPT WITH (NOLOCK)
   JOIN RECEIPTDETAIL(NOLOCK) ON RECEIPT.Receiptkey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU  WITH (NOLOCK) ON (RECEIPTDETAIL.Storerkey = SKU.Storerkey)
                           AND(RECEIPTDETAIL.Sku = SKU.Sku)
   WHERE RECEIPT.Receiptkey = @c_Receiptkey
   GROUP BY Receipt.Facility
          ,Receipt.FinalizeDate
          ,Receipt.IncoTerms
          ,Receipt.UserDefine01
          ,Receipt.UserDefine02
          ,Receipt.ExternReceiptKey
          ,ReceiptDetail.ExternLineNo
          ,ReceiptDetail.SKU
          ,SKU.DESCR
          ,SKU.Style
          ,SKU.Size
          ,ReceiptDetail.UserDefine01
          ,ReceiptDetail.UserDefine02 
          ,RECEIPTDETAIL.RECEIPTLINENUMBER
   ORDER BY RECEIPTDETAIL.RECEIPTLINENUMBER
   
END -- procedure

GO