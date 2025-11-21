SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_ASN_SKULABEL_001                           */
/* Creation Date: 27-Jul-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20319 - JP Dcode DCJ SKU Label                          */
/*                                                                      */
/* Called By: RPT_ASN_SKULABEL_001                                      */
/*                                                                      */
/* GitLab Version: 1.2                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 27-Jul-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 15-Sep-2022  WLChooi  1.1  WMS-20319 - Add SKU.ALTSKU (WL01)         */
/* 26-Oct-2022  WLChooi  1.2  WMS-20914 - Add SKU.busr1 (WL02)          */
/************************************************************************/
CREATE PROC [dbo].[isp_RPT_ASN_SKULABEL_001]
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
         , @n_Count           INT

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   SELECT @n_Count = SUM(RD.QtyExpected)
   FROM RECEIPTDETAIL RD (NOLOCK)
   WHERE RD.ReceiptKey = @c_Receiptkey

   ;WITH t1 AS ( SELECT RD.Sku, SUM(RD.QtyExpected) AS QtyExpected, S.CLASS, S.Color, S.Size, S.BUSR1   --WL01   --WL02
                FROM RECEIPTDETAIL RD (NOLOCK)
                JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.Sku = RD.Sku
                WHERE RD.ReceiptKey = @c_Receiptkey
                GROUP BY RD.Sku, S.CLASS, S.Color, S.Size, S.BUSR1),   --WL01   --WL02 
        t2 AS ( SELECT TOP (@n_Count) ROW_NUMBER() OVER (ORDER BY ID) AS Val FROM sysobjects (NOLOCK)  )
   SELECT t1.Sku, t1.CLASS, t1.Color, t1.Size, t1.BUSR1   --WL01   --WL02 
   FROM t1, t2
   WHERE t1.QtyExpected >= t2.Val 
   ORDER BY t1.Sku

END -- procedure

GO