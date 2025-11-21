SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptTallySheet85                                 */  
/* Creation Date: 17-FEB-2022                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-18896 - [KR] COLLAGE_Inbound TallySheet_DW_New          */  
/*        : Copy from isp_ReceiptTallySheet71 and modify                */  
/*                                                                      */  
/* Called By: r_receipt_tallysheet85                                    */  
/*          :                                                           */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 2022-02-17   CSCHONG   1.0 Devops Scripts Combine                    */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ReceiptTallySheet85]
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

   CREATE TABLE #TMP_TS85 (
      Receiptkey          NVARCHAR(10)  NULL,
      ExternReceiptkey    NVARCHAR(20)  NULL,
      ReceiptDate         DATETIME NULL,
      SKU                 NVARCHAR(20)  NULL,
      DESCR               NVARCHAR(250) NULL,
      PAckkey             NVARCHAR(10)  NULL,
      QtyExpected         FLOAT NULL,
      InspectionQty       FLOAT NULL,
      [Getdate]           NVARCHAR(16)  NULL,
      RptTitle            NVARCHAR(150)  NULL ,
      LOTT04              NVARCHAR(10) 
   )

   INSERT INTO #TMP_TS85
   SELECT R.Receiptkey
        , R.ExternReceiptkey
        , R.ReceiptDate
        , RD.SKU
        , SKU.DESCR
        , RD.PackKey
        , SUM(RD.QtyExpected) AS QtyExpected
        , CEILING(SUM(RD.QtyExpected) * 0.03) AS InspectionQty
        , CONVERT(CHAR(16), GetDate(), 120) AS [GetDate]
        , 'COLLAGE Inbound Tally Sheet' AS Rpttitle
        , CONVERT(NVARCHAR(10),RD.Lottable04,23) AS LOTT04
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON RD.Receiptkey = R.Receiptkey
   JOIN SKU (NOLOCK) ON RD.SKU = SKU.SKU AND RD.Storerkey = SKU.Storerkey
  -- JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey
   WHERE R.Storerkey BETWEEN @c_StorerkeyStart AND @c_StorerkeyEnd
   AND R.ReceiptKey BETWEEN @c_ReceiptkeyStart AND @c_ReceiptkeyEnd
   GROUP BY R.Receiptkey
        , R.ExternReceiptkey
        , R.ReceiptDate
        , RD.SKU
        , SKU.DESCR
        , RD.PackKey
        , CONVERT(NVARCHAR(10),RD.Lottable04,23)
   ORDER BY R.ReceiptKey, RD.Sku
   
   SELECT * FROM #TMP_TS85 (NOLOCK)
   ORDER BY ReceiptKey, Sku

QUIT_SP:  
   IF OBJECT_ID('tempdb..#TMP_TS85') IS NOT NULL
      DROP TABLE #TMP_TS85
      
END -- procedure

GO