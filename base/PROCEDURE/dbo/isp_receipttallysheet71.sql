SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptTallySheet71                                 */  
/* Creation Date: 23-Dec-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15947 - iiCombined KR Tally Sheet                       */  
/*        : Copy from isp_ReceiptTallySheet70 and modify                */  
/*                                                                      */  
/* Called By: r_receipt_tallysheet71                                    */  
/*          :                                                           */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 2021-05-11   WLChooi   1.1 WMS-16953 - Add Receiptdetail.Userdefine01*/
/*                            (WL01)                                    */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ReceiptTallySheet71]
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

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   CREATE TABLE #TMP_TS71 (
   	Receiptkey          NVARCHAR(10)  NULL,
   	ExternReceiptkey    NVARCHAR(20)  NULL,
   	ReceiptDate         DATETIME NULL,
   	SKU                 NVARCHAR(20)  NULL,
   	DESCR               NVARCHAR(250) NULL,
   	[Box]               FLOAT NULL,
   	QtyExpected         FLOAT NULL,
   	InspectionQty       FLOAT NULL,
   	[Getdate]           NVARCHAR(16)  NULL,
      UCCNo               NVARCHAR(20)  NULL   --WL01
   )

   INSERT INTO #TMP_TS71
   SELECT R.Receiptkey
        , R.ExternReceiptkey
        , R.ReceiptDate
        , RD.SKU
        , SKU.DESCR
        , (SELECT COUNT(DISTINCT RECDET.UserDefine01) FROM RECEIPTDETAIL RECDET (NOLOCK)
           WHERE RECDET.Receiptkey = R.Receiptkey AND RECDET.SKU = RD.SKU) AS [Box]
        , SUM(RD.QtyExpected) AS QtyExpected
        , CEILING(SUM(RD.QtyExpected) * 0.03) AS InspectionQty
        , CONVERT(CHAR(16), GetDate(), 120) AS [GetDate]
        , ISNULL(RD.UserDefine01,'')   --WL01
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON RD.Receiptkey = R.Receiptkey
   JOIN SKU (NOLOCK) ON RD.SKU = SKU.SKU AND RD.Storerkey = SKU.Storerkey
   JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey
   WHERE R.Storerkey BETWEEN @c_StorerkeyStart AND @c_StorerkeyEnd
   AND R.ReceiptKey BETWEEN @c_ReceiptkeyStart AND @c_ReceiptkeyEnd
   GROUP BY R.Receiptkey
        , R.ExternReceiptkey
        , R.ReceiptDate
        , RD.SKU
        , SKU.DESCR
        , PACK.CaseCnt
        , ISNULL(RD.UserDefine01,'')   --WL01
   ORDER BY R.ReceiptKey, RD.Sku
   
   SELECT * FROM #TMP_TS71 (NOLOCK)
   ORDER BY ReceiptKey, Sku, UCCNo   --WL01

QUIT_SP:  
   IF OBJECT_ID('tempdb..#TMP_TS71') IS NOT NULL
      DROP TABLE #TMP_TS71
      
END -- procedure

GO