SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_ReceiptTallySheet70_ab                              */
/* Creation Date: 27-JUL-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-20169 -KR_Allbirds_Tally Sheet Report -                 */
/*        :                                                             */
/* Called By: r_receipt_tallysheet70_ab                                 */
/*           Duplicate from r_receipt_tallysheet70                      */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2022-07-27   CHONGCS   1.1 Devops Scripts Combine                    */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet70_ab]
            @c_ReceiptkeyStart   NVARCHAR(15)
          , @c_ReceiptkeyEnd     NVARCHAR(15)
          , @c_StorerkeyStart    NVARCHAR(15)
          , @c_StorerkeyEnd      NVARCHAR(15)
          , @c_UserID            NVARCHAR(100) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @b_Success         INT
         , @n_Err             INT
         , @c_Errmsg          NVARCHAR(255)
         , @c_ShowBlankDetail NVARCHAR(10) = 'N'   
         , @n_MaxLinePerPage  INT = 20      
         , @n_Count           INT = 1       

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @c_Errmsg    = ''


   CREATE TABLE #TMP_TS70ab (
      Receiptkey          NVARCHAR(10)  NULL,
      ExternReceiptkey    NVARCHAR(20)  NULL,
      ReceiptDate         DATETIME NULL,
      SKU                 NVARCHAR(20)  NULL,
      DESCR               NVARCHAR(250) NULL,
      [Box]               DECIMAL(10,1) NULL,
      QtyExpected         FLOAT NULL,
      InspectionQty       FLOAT NULL,
      [Getdate]           NVARCHAR(16)  NULL,
      Packkey             NVARCHAR(20)  NULL,
   -- UCCQty              INT NULL,
      Storerkey           NVARCHAR(20),
      ItemType            NVARCHAR(20) NULL     
   )


      INSERT INTO #TMP_TS70ab   
      SELECT R.Receiptkey
           , R.ExternReceiptkey
           , R.ReceiptDate
           , RD.SKU
           , SKU.DESCR
           , CASE WHEN ISNULL(PACK.Casecnt,0) > 0 AND ISNUMERIC(PACK.CaseCnt) = 1
                  THEN SUM(RD.QtyExpected) / PACK.CaseCnt ELSE 0 END AS [Box]
           , SUM(RD.QtyExpected) AS QtyExpected
           , CASE WHEN ISNULL(ST.PercentA,0) > 0 AND ISNUMERIC(ST.PercentA) = 1
                  THEN SUM(RD.QtyExpected) * ST.PercentA ELSE 0 END AS InspectionQty
           , CONVERT(CHAR(16), GetDate(), 120) AS [GetDate]
           , PACK.Packkey   
           , R.StorerKey   
           , SKU.itemclass
      FROM RECEIPT R (NOLOCK)
      JOIN RECEIPTDETAIL RD (NOLOCK) ON RD.Receiptkey = R.Receiptkey
      JOIN SKU (NOLOCK) ON RD.SKU = SKU.SKU AND RD.Storerkey = SKU.Storerkey
      JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey
      JOIN STORER ST (NOLOCK) ON ST.Storerkey = R.StorerKey
      WHERE R.Storerkey BETWEEN @c_StorerkeyStart AND @c_StorerkeyEnd
      AND R.ReceiptKey BETWEEN @c_ReceiptkeyStart AND @c_ReceiptkeyEnd
      GROUP BY R.Receiptkey
           , R.ExternReceiptkey
           , R.ReceiptDate
           , RD.SKU
           , SKU.DESCR
           , PACK.CaseCnt
           , ST.PercentA
           , PACK.Packkey
           , R.StorerKey
           , SKU.itemclass
      ORDER BY R.ReceiptKey, RD.Sku



   SELECT * FROM #TMP_TS70ab (NOLOCK)
   ORDER BY ReceiptKey, Sku


QUIT_SP:
END -- procedure


GO