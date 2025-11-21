SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_ReceiptDetailDiscrep07                         */
/* Creation Date: 14-Aug-2018                                           */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose:WMS-5773-[CN] Levi's B2B - Receipt Discrepancy report        */
/*                                                                      */
/* Called By: r_receipt_discrepancy07                                   */
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
CREATE PROC [dbo].[isp_ReceiptDetailDiscrep07] (
@c_ReceiptKey          NVARCHAR(18)
) AS
BEGIN
   
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_storerkey       NVARCHAR(20)

   SET @c_storerkey = ''

   SELECT TOP 1 @c_storerkey = R.Storerkey
   FROM RECEIPT R WITH (NOLOCK)
   WHERE R.receiptkey = @c_ReceiptKey

   SELECT DISTINCT R.Receiptkey AS 'S_O',
                   R.ExternReceiptKey AS 'Org_S_O',
                   R.EditDate AS 'Date', 
                   R.Carrierkey AS 'Ship_To',
                   S.Style AS 'Material',
                   S.[Size] AS 'Grid_Value',
                   RD.QtyExpected AS 'Org_Qty',
                   RD.BeforereceivedQty As 'Scan_Qty',
                   (RD.BeforereceivedQty - RD.QtyExpected) As 'Variance_Qty',
                   CASE WHEN (RD.BeforereceivedQty - RD.QtyExpected) < 0 THEN 'unmatch SKU&Qty' ELSE '' END AS 'Remarks' 
   FROM Receipt R WITH (NOLOCK)
   JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.Receiptkey = R.receiptkey
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = RD.storerkey and S.sku = RD.sku 
   WHERE R.StorerKey = @c_StorerKey
   AND R.ReceiptKey = @c_ReceiptKey
   ORDER BY S.Style,S.[Size]
  
END


GO