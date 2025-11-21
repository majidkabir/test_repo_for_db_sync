SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_receiptsummary13                                    */
/* Creation Date: 13-Jan-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16032 - [PH] - Adidas Ecom - Inventory Receipt Report   */
/*                                                                      */
/* Called By: r_dw_receipt_summary13                                    */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_receiptsummary13]  (
           @c_Receiptkey         NVARCHAR(10)
)
AS                                 
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT S.Style, SUM(RD.QtyReceived) AS Qty
   INTO #TMP_SUM13
   FROM RECEIPTDETAIL RD (NOLOCK)
   JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.Sku = RD.SKU
   WHERE RD.ReceiptKey = @c_Receiptkey
   GROUP BY S.Style
   
   SELECT DISTINCT 
          R.Facility
        , R.StorerKey
        , R.EffectiveDate
        , R.ReceiptKey
        , R.POKey
        , S.Style
        , (SELECT TOP 1 DESCR FROM SKU (NOLOCK) WHERE StorerKey = R.Storerkey AND Style = S.Style)
        , T.Qty
        , RD.UOM
        , ISNULL(ST.Company,'')
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.Sku = RD.Sku
   JOIN #TMP_SUM13 T ON T.Style = S.Style 
   LEFT JOIN STORER ST (NOLOCK) ON ST.Storerkey = R.StorerKey
   WHERE R.ReceiptKey = @c_Receiptkey

   IF OBJECT_ID('tempdb..#TMP_SUM13') IS NOT NULL
      DROP TABLE #TMP_SUM13

END

GO