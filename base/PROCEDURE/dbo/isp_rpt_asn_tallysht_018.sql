SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_ASN_TALLYSHT_018                           */
/* Creation Date: 04-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20439 - JP Dcode DCJ Tally Sheet                        */
/*                                                                      */
/* Called By: RPT_ASN_TALLYSHT_018                                      */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 04-Aug-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_RPT_ASN_TALLYSHT_018]
         @c_Receiptkey        NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   SELECT R.Receiptkey
        , TRIM(R.ExternReceiptKey) AS ExternReceiptKey
        , R.ReceiptDate
        , R.Storerkey
        , RD.ReceiptLineNumber
        , TRIM(RD.Sku) AS SKU
        , RD.QtyExpected
        , (SELECT SUM(RDET.QtyExpected) 
           FROM RECEIPTDETAIL RDET (NOLOCK) 
           WHERE RDET.ReceiptKey = R.ReceiptKey) AS SumQtyExpected
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
   WHERE R.ReceiptKey = @c_Receiptkey
   ORDER BY RD.ReceiptLineNumber

QUIT_SP:  
END -- procedure

GO