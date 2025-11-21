SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_ASN_TALLYSHT_007                              */
/* Creation Date: 04-FEB-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18870                                                      */
/*                                                                         */
/* Called By: RPT_ASN_TALLYSHT_007                                         */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author      Ver. Purposes                                  */
/* 07-Feb-2022  WLChooi     1.0  DevOps Combine Script                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_RPT_ASN_TALLYSHT_007]
      @c_Receiptkey         NVARCHAR(10)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT RECEIPT.STORERKEY
         ,RECEIPTDETAIL.Toloc as Toloc
         ,ISNULL(CL1.DESCRIPTION,'') AS CLKUPDESCR
         ,CONVERT(nvarchar(10),RECEIPT.RECEIPTDATE,111) AS RECEIPTDATE
         ,RECEIPT.Facility as Facility
         ,ISNULL(RECEIPT.Notes,'') as RNotes
         ,RECEIPT.BilledContainerQty as BilledContainerQty
         ,ISNULL(RECEIPT.CONTAINERKEY,'') as CONTAINERKEY
         ,RECEIPT.Receiptkey as receiptkey
         ,RECEIPT.ExternReceiptkey as ExternReceiptkey
         ,S.Style AS SStyle
         ,S.Color as SColor
         ,S.[Size] AS SSize
         ,RECEIPTDETAIL.Sku  as SKU
         ,S.Descr AS SDESCR
         ,RECEIPTDETAIL.lottable03 as LOTT03
         ,RECEIPTDETAIL.Qtyexpected
         ,RECEIPTDETAIL.QtyReceived
   FROM RECEIPTDETAIL WITH (NOLOCK)
   JOIN RECEIPT WITH (NOLOCK) ON (RECEIPT.RECEIPTKEY = RECEIPTDETAIL.RECEIPTKEY)
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = RECEIPTDETAIL.Storerkey AND S.Sku = RECEIPTDETAIL.Sku
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME = 'Containert' AND CL1.STORERKEY = RECEIPT.STORERKEY
                                       AND CL1.code = RECEIPT.ContainerType
   WHERE ( RECEIPT.ReceiptKey =  @c_Receiptkey )
   ORDER BY  RECEIPT.Receiptkey,RECEIPTDETAIL.Sku

END

GO