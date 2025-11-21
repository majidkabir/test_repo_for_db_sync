SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_RPT_ASN_TALLYSHT_029                           */        
/* CreatiON Date: 11-JUL-2023                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-22868 (TW)                                              */      
/*                                                                      */        
/* Called By: RPT_ASN_TALLYSHT_029            									*/        
/*                                                                      */        
/* PVCS VersiON: 1.0                                                    */        
/*                                                                      */        
/* VersiON: 7.0                                                         */        
/*                                                                      */        
/* Data ModificatiONs:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 11-JUL-2023  WZPang   1.0  DevOps Combine Script                     */
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_ASN_TALLYSHT_029] (
      @c_Receiptkey NVARCHAR(10)    
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        

   SELECT  RECEIPT.Receiptkey
         , RECEIPT.Notes
         , RECEIPT.ExternReceiptkey
         , RECEIPT.UserDefine01 AS ReceiptUserDefine01
         , RECEIPT.ReceiptDate
         , RECEIPT.BilledContainerQty
         , RECEIPTDETAIL.UserDefine01 AS ReceiptDetailUserDefine01
         , (SELECT SUM(RD.QtyExpected)
           FROM RECEIPTDETAIL RD(NOLOCK)
           WHERE RD.Receiptkey = @c_Receiptkey AND RECEIPTDETAIL.UserDefine01 = RD.UserDefine01) AS SUMQtyExpected
         , RECEIPTDETAIL.SKU
         , SKU.DESCR
         , RECEIPTDETAIL.QtyExpected
         , RECEIPTDETAIL.ToId
         , '' AS EmptyRemark
         , DENSE_RANK() OVER (PARTITION BY RECEIPT.Receiptkey ORDER BY  RECEIPTDETAIL.UserDefine01) AS RowNo
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU (NOLOCK) ON RECEIPTDETAIL.Sku = SKU.Sku
   WHERE RECEIPT.Receiptkey = @c_Receiptkey
   GROUP BY RECEIPT.Receiptkey
         , RECEIPT.Notes
         , RECEIPT.ExternReceiptkey
         , RECEIPT.UserDefine01 
         , RECEIPT.ReceiptDate
         , RECEIPT.BilledContainerQty
         , RECEIPTDETAIL.UserDefine01
         , RECEIPTDETAIL.SKU
         , SKU.DESCR
         , RECEIPTDETAIL.QtyExpected
         , RECEIPTDETAIL.ToId
   ORDER BY RECEIPTDETAIL.UserDefine01

END -- procedure    

GO