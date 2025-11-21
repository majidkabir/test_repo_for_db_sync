SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_ReceiptSummary09                                        */
/* Creation Date: 19-SEP-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  r_dw_receipt_summary09                                     */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 30-Nov-2016  CSCHONG   1.0 WMS-730 change field mapping (CS01)       */
/************************************************************************/
CREATE PROC [dbo].[isp_ReceiptSummary09] 
            @c_ReceiptKey  NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   CREATE TABLE #TMP_BRAND
   (  ExternPOKey    NVARCHAR(20)  NULL
   ,  Brand          NVARCHAR(60)  NULL
   ,  DistinctBrand  INT  NULL
   )

   INSERT INTO #TMP_BRAND
   (  ExternPOKey
   ,  Brand
   ,  DistinctBrand
   )
   SELECT ExternPOKey  = ISNULL(RTRIM(RECEIPTDETAIL.ExternPOKey),'')
         ,ItemClass    = ISNULL(MIN(RTRIM(CL.Description)),'')
         ,DistinctBrand=COUNT(DISTINCT ISNULL(RTRIM(CL.Description),''))
   FROM RECEIPTDETAIL WITH (NOLOCK)  
   JOIN SKU           WITH (NOLOCK) ON (RECEIPTDETAIL.Storerkey = SKU.Storerkey)
                                    AND(RECEIPTDETAIL.Sku = SKU.Sku)
   LEFT JOIN CODELKUP CL   WITH (NOLOCK) ON (CL.ListName = 'ItemClass')
                                         AND(CL.Code = SKU.ItemClass)
   WHERE RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
   GROUP BY ISNULL(RTRIM(RECEIPTDETAIL.ExternPOKey),'')


   UPDATE #TMP_BRAND
      SET Brand = CASE WHEN #TMP_BRAND.DistinctBrand > 1 THEN 'Mixed Brand' ELSE #TMP_BRAND.Brand END

   SELECT CustomerGroupName = ISNULL(RTRIM(STORER.CustomerGroupName),'')
         ,ContainerKey      = ISNULL(RTRIM(RECEIPT.ContainerKey),'')
         ,Brand             = #TMP_BRAND.Brand 
         ,RECEIPT.Receiptdate
         ,ExternPOKey       = ISNULL(RTRIM(RECEIPTDETAIL.ExternPOKey),'')
         ,UserDefine01      = ISNULL(RTRIM(RECEIPTDETAIL.UserDefine01),'')
         ,RECEIPTDETAIL.Storerkey          
         ,RECEIPTDETAIL.Sku
         ,Descr        = ISNULL(RTRIM(SKU.Descr),'')
         ,RetailSku    = ISNULL(RTRIM(SKU.RetailSku),'')
         ,Style        = ISNULL(RTRIM(SKU.Style),'')
         ,Color        = ISNULL(RTRIM(SKU.Color),'')
         ,Size         = ISNULL(RTRIM(SKU.Size),'')
         ,ItemClass    = ISNULL(RTRIM(SKU.ItemClass),'')

         ,QtyExpected  = ISNULL(SUM(RECEIPTDETAIL.QtyExpected),0)
         ,QtyReceived  = (ISNULL(SUM(RECEIPTDETAIL.QtyReceived),0) + ISNULL(SUM(RECEIPTDETAIL.BeforeReceivedQty),0))  --(CS01)
         ,QtyVariance  = ISNULL(SUM(RECEIPTDETAIL.QtyReceived - RECEIPTDETAIL.QtyExpected ),0) 
   FROM RECEIPT WITH (NOLOCK)
   JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)
   JOIN STORER        WITH (NOLOCK) ON (RECEIPT.Storerkey = STORER.Storerkey)
   JOIN SKU           WITH (NOLOCK) ON (RECEIPTDETAIL.Storerkey = SKU.Storerkey)
                                    AND(RECEIPTDETAIL.Sku = SKU.Sku)
   JOIN #TMP_BRAND                  ON (ISNULL(RTRIM(RECEIPTDETAIL.ExternPOKey),'') = #TMP_BRAND.ExternPOKey )
   WHERE RECEIPT.ReceiptKey = @c_ReceiptKey
   GROUP BY ISNULL(RTRIM(STORER.CustomerGroupName),'')
         ,  ISNULL(RTRIM(RECEIPT.ContainerKey),'')
         ,  RECEIPT.Receiptdate
         ,  #TMP_BRAND.Brand 
         ,  ISNULL(RTRIM(RECEIPTDETAIL.ExternPOKey),'')
         ,  ISNULL(RTRIM(RECEIPTDETAIL.UserDefine01),'')
         ,  RECEIPTDETAIL.Storerkey
         ,  RECEIPTDETAIL.Sku
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  ISNULL(RTRIM(SKU.RetailSku),'')
         ,  ISNULL(RTRIM(SKU.Style),'')
         ,  ISNULL(RTRIM(SKU.Color),'')
         ,  ISNULL(RTRIM(SKU.Size),'')
         ,  ISNULL(RTRIM(SKU.ItemClass),'')



QUIT_SP:
END -- procedure

GO