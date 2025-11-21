SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_ASN_TALLYSHT_028                                */
/* Creation Date: 02-May-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22365 - [TW]PRT_LogiReport_TallySheet NEW               */
/*                                                                      */
/* Called By: RPT_ASN_TALLYSHT_028                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 02-May-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_ASN_TALLYSHT_028] @c_Receiptkey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT           = 1
         , @n_err       INT           = 0
         , @c_errmsg    NVARCHAR(255) = N''
         , @b_Success   INT           = 1
         , @n_StartTCnt INT           = @@TRANCOUNT

   SELECT R.StorerKey
        , R.ExternReceiptKey
        , RD.ReceiptKey
        , R.ContainerKey
        , ISNULL(CL1.[Description], '') AS ContainerType
        , R.ReceiptDate
        , RD.ToLoc
        , CAST(RD.ReceiptLineNumber AS INT) AS ReceiptLineNumber
        , RD.Sku
        , RD.Lottable02
        , S.DESCR
        , S.BUSR6
        , S.BUSR7
        , CAST(ISNULL(P.PalletTI, 0) AS NVARCHAR) + 'x' + CAST(ISNULL(P.PalletHI, 0) AS NVARCHAR) AS LxW
        , CASE WHEN P.CaseCnt > 0 THEN FLOOR(SUM(RD.QtyExpected) / P.CaseCnt)
               ELSE 0 END AS CaseQty
        , CASE WHEN P.CaseCnt > 0 THEN SUM(RD.QtyExpected) % CAST(P.CaseCnt AS INT)
               ELSE SUM(RD.QtyExpected) END AS LooseQty
        , SUM(RD.QtyExpected) AS QtyReceived
        , S.MANUFACTURERSKU
        , S.RETAILSKU
        , S.ALTSKU
        , ISNULL(CL2.Notes,'') AS Notes
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.Sku = RD.Sku
   JOIN PACK P (NOLOCK) ON S.PACKKey = P.PackKey
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON  CL1.LISTNAME = 'CONTAINERT'
                                   AND CL1.Code = R.ContainerType
                                   AND CL1.Storerkey = R.StorerKey
   LEFT JOIN CODELKUP CL2 (NOLOCK) ON  CL2.LISTNAME = 'REPORTCFG'
                                   AND CL2.Code = 'TALLYSHT'
                                   AND CL2.code2 = 'ReceiptA'
                                   AND CL2.Storerkey = R.StorerKey
   WHERE R.ReceiptKey = @c_Receiptkey
   GROUP BY R.StorerKey
          , R.ExternReceiptKey
          , RD.ReceiptKey
          , R.ContainerKey
          , ISNULL(CL1.[Description], '')
          , R.ReceiptDate
          , RD.ToLoc
          , CAST(RD.ReceiptLineNumber AS INT)
          , RD.Sku
          , RD.Lottable02
          , S.DESCR
          , S.BUSR6
          , S.BUSR7
          , CAST(ISNULL(P.PalletTI, 0) AS NVARCHAR) + 'x' + CAST(ISNULL(P.PalletHI, 0) AS NVARCHAR)
          , P.CaseCnt 
          , S.MANUFACTURERSKU
          , S.RETAILSKU
          , S.ALTSKU
          , ISNULL(CL2.Notes,'')
   ORDER BY CAST(RD.ReceiptLineNumber AS INT)
END

GO