SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptTallySheet80                                 */  
/* Creation Date: 18-Jun-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-17304 - SG - aCommerce-Adidas - Tally Sheet             */   
/*        :                                                             */  
/* Called By: r_receipt_tallysheet80                                    */
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 2021-09-14   Mingle    1.1 WMS-17854 add externreceiptkey and modify */
/*                                      sorting(ML01)                   */
/************************************************************************/ 

CREATE PROC [dbo].[isp_ReceiptTallySheet80]  
            @c_ReceiptKeyStart   NVARCHAR(10)  
         ,  @c_ReceiptKeyEnd     NVARCHAR(10)  
         ,  @c_StorerKeyStart    NVARCHAR(15)  
         ,  @c_StorerKeyEnd      NVARCHAR(15) 
  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @n_continue     INT = 1, @n_err INT = 0, @c_errmsg NVARCHAR(255) = '', @b_Success INT = 1
   DECLARE @n_StartTCnt    INT = @@TRANCOUNT
         , @c_Containerkey NVARCHAR(18) = ''
   
   IF @c_ReceiptKeyStart = @c_ReceiptKeyEnd
   BEGIN
      SELECT @c_Containerkey = RECEIPT.ContainerKey
      FROM RECEIPT (NOLOCK)
      WHERE ReceiptKey = @c_ReceiptKeyStart
   END

   IF ISNULL(@c_Containerkey,'') = ''
   BEGIN
      SELECT R.ReceiptKey
           , ISNULL(ST.Company,'') AS Principal
           , ''
           , R.Signatory
           , R.ContainerKey
           , RD.POKey
           , RD.ToLoc
           , SUM(RD.QtyExpected) AS QtyExpected
           , (SELECT COUNT(DISTINCT ReceiptLineNumber) FROM RECEIPTDETAIL (NOLOCK) WHERE ReceiptKey = R.ReceiptKey) AS TotalASNLine
           , S.Sku
           , ISNULL(S.DESCR,'') AS SKUDESCR
           , ISNULL(S.BUSR6,'') AS SKUBUSR6
           , ISNULL(S.MANUFACTURERSKU,'') AS MANUFACTURERSKU
           , ISNULL(CL.[Description],'') AS SKUGROUP
           , RD.UOM
           , ''
           , R.ExternReceiptkey     --ML01
      FROM RECEIPT R (NOLOCK)
      JOIN RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
      JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.SKU = RD.SKU
      JOIN STORER ST (NOLOCK) ON ST.StorerKey = R.StorerKey
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'SKUGROUP' AND CL.Code = S.SKUGROUP
                                    AND CL.Storerkey = R.StorerKey
      WHERE R.ReceiptKey BETWEEN @c_ReceiptKeyStart AND @c_ReceiptKeyEnd
      AND R.StorerKey BETWEEN @c_StorerKeyStart AND @c_StorerKeyEnd
      GROUP BY R.ReceiptKey
             , ISNULL(ST.Company,'')
             , R.Signatory
             , R.ContainerKey
             , RD.POKey
             , RD.ToLoc
             , S.SKU
             , ISNULL(S.DESCR,'')
             , ISNULL(S.BUSR6,'')
             , ISNULL(S.MANUFACTURERSKU,'')
             , ISNULL(CL.[Description],'')
             , RD.UOM
             , R.ExternReceiptkey     --ML01
      --ORDER BY R.ReceiptKey, R.ContainerKey, S.SKU
      ORDER BY R.ExternReceiptkey,S.SKU     --ML01
   END
   ELSE
   BEGIN
      SELECT R.ReceiptKey
           , ISNULL(ST.Company,'') AS Principal
           , ''
           , R.Signatory
           , R.ContainerKey
           , RD.POKey
           , RD.ToLoc
           , SUM(RD.QtyExpected) AS QtyExpected
           , (SELECT COUNT(DISTINCT RECEIPTDETAIL.ReceiptKey + RECEIPTDETAIL.ReceiptLineNumber) 
              FROM RECEIPTDETAIL (NOLOCK) 
              JOIN RECEIPT (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
              WHERE RECEIPT.ContainerKey = R.ContainerKey) AS TotalASNLine
           , RD.Sku
           , ISNULL(S.DESCR,'') AS SKUDESCR
           , ISNULL(S.BUSR6,'') AS SKUBUSR6
           , ISNULL(S.MANUFACTURERSKU,'') AS MANUFACTURERSKU
           , ISNULL(CL.[Description],'') AS SKUGROUP
           , RD.UOM
           , ''
           , R.ExternReceiptkey     --ML01
      FROM RECEIPT R (NOLOCK)
      JOIN RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
      JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.SKU = RD.SKU
      JOIN STORER ST (NOLOCK) ON ST.StorerKey = R.StorerKey
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'SKUGROUP' AND CL.Code = S.SKUGROUP
                                    AND CL.Storerkey = R.StorerKey
      WHERE R.ContainerKey = @c_Containerkey
      AND R.StorerKey BETWEEN @c_StorerKeyStart AND @c_StorerKeyEnd
      GROUP BY R.ReceiptKey
             , ISNULL(ST.Company,'')
             , R.Signatory
             , R.ContainerKey
             , RD.POKey
             , RD.ToLoc
             , RD.SKU
             , ISNULL(S.DESCR,'')
             , ISNULL(S.BUSR6,'')
             , ISNULL(S.MANUFACTURERSKU,'')
             , ISNULL(CL.[Description],'')
             , RD.UOM
             , R.ExternReceiptkey     --ML01
      ORDER BY RD.SKU
   END 
END

GO