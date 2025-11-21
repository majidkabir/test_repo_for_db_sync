SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptTallySheet70                                 */  
/* Creation Date: 12-Aug-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-14666 - Allbirds KR Tally Sheet                         */  
/*        :                                                             */  
/* Called By: r_receipt_tallysheet70                                    */  
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 2020-09-09   WLChooi   1.1 WMS-15013 - Cater for ADIDAS - Show blank */
/*                            Detail Lines (WL01)                       */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ReceiptTallySheet70]
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
         , @c_ShowBlankDetail NVARCHAR(10) = 'N'   --WL01
         , @n_MaxLinePerPage  INT = 20       --WL01
         , @n_Count           INT = 1        --WL01

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   --WL01 START
   CREATE TABLE #TMP_TS70 (
   	Receiptkey          NVARCHAR(10)  NULL,
   	ExternReceiptkey    NVARCHAR(20)  NULL,
   	ReceiptDate         DATETIME NULL,
   	SKU                 NVARCHAR(20)  NULL,
   	DESCR               NVARCHAR(250) NULL,
   	[Box]               FLOAT NULL,
   	QtyExpected         FLOAT NULL,
   	InspectionQty       FLOAT NULL,
   	[Getdate]           NVARCHAR(16)  NULL,
   	ShowBlankDetail     NVARCHAR(10)  NULL,
   	UCCQty              INT NULL
   )
   
   SELECT @c_ShowBlankDetail = ISNULL(CODELKUP.Short,'N')
   FROM CODELKUP (NOLOCK)
   WHERE CODELKUP.LISTNAME = 'REPORTCFG'
   AND CODELKUP.Code = 'ShowBlankDetail'
   AND CODELKUP.Long = 'r_receipt_tallysheet70'
   AND CODELKUP.Storerkey = @c_StorerkeyStart
   
   IF @c_ShowBlankDetail = 'Y'
   BEGIN
   	WHILE(@n_MaxLinePerPage > 0)
   	BEGIN
   		INSERT INTO #TMP_TS70
   	   SELECT TOP 1 R.Receiptkey, R.ExternReceiptkey, R.ReceiptDate, NULL, NULL, NULL, NULL, NULL, CONVERT(CHAR(16), GetDate(), 120) AS [GetDate], @c_ShowBlankDetail, ISNULL(RD.UCCQty,0)
   	   FROM RECEIPT R (NOLOCK)
   	   OUTER APPLY (SELECT TOP 1 CEILING(COUNT(DISTINCT U.UCCNo) * 0.03) AS UCCQty
   	                FROM RECEIPTDETAIL RD (NOLOCK)
   	                JOIN UCC U (NOLOCK) ON U.ExternKey = RD.ExternReceiptKey AND U.Storerkey = RD.StorerKey
   	                                   AND U.SKU = RD.SKU
   	                WHERE RD.ReceiptKey = R.ReceiptKey AND RD.StorerKey = R.StorerKey) AS RD
   	   WHERE R.Storerkey BETWEEN @c_StorerkeyStart AND @c_StorerkeyEnd
         AND R.ReceiptKey BETWEEN @c_ReceiptkeyStart AND @c_ReceiptkeyEnd   
         		
   		SET @n_MaxLinePerPage = @n_MaxLinePerPage - 1
   	END
   END
   ELSE
   BEGIN 
   	INSERT INTO #TMP_TS70   --WL01 END
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
           , @c_ShowBlankDetail   --WL01
           , 0 AS UCCQty   --WL01
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
      ORDER BY R.ReceiptKey, RD.Sku
   END   --WL01
   
   --WL01 START
   SELECT * FROM #TMP_TS70 (NOLOCK)
   ORDER BY ReceiptKey, Sku
   --WL01 END

QUIT_SP:  
END -- procedure


GO