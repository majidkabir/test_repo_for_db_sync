SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure:isp_RPT_ASN_PTWYDET_001                              */
/* Creation Date: 12-Jun-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-22728                                                    */
/*                                                                       */
/* Called By: RPT_ASN_PTWYDET_001                                        */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 12-Jun-2023 WLChooi 1.0   DevOps Combine Script                       */
/*************************************************************************/
CREATE   PROC [dbo].[isp_RPT_ASN_PTWYDET_001]
(@c_Receiptkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT RD.ExternPoKey
        , RD.ToId
        , RD.ToLoc
        , RD.Sku
        , S.DESCR
        , RD.Lottable02
        , RD.UOM
        , RD.QtyExpected AS QtyPcs_Expctd
        , CASE WHEN ISNULL(P.CaseCnt, 0) = 0 THEN 0
               ELSE RD.QtyExpected / P.CaseCnt END AS QtyCtn_Expctd
        , RD.QtyReceived AS QtyPcs_Rcvd
        , CASE WHEN ISNULL(RD.QtyReceived, 0) = 0 OR ISNULL(P.CaseCnt, 0) = 0 THEN 0
               ELSE RD.QtyReceived / P.CaseCnt END AS QtyCtn_Rcvd
        , R.ContainerKey
        , R.CarrierReference
        , R.WarehouseReference
        , R.Facility
        , R.ReceiptKey
   FROM RECEIPT R WITH (NOLOCK)
   JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
   JOIN SKU S WITH (NOLOCK) ON RD.StorerKey = S.StorerKey AND RD.Sku = S.Sku
   JOIN PACK P WITH (NOLOCK) ON S.PACKKey = P.PackKey
   WHERE R.ReceiptKey = @c_Receiptkey

   QUIT_SP:
END

GO