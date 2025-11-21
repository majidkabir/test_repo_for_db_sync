SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_RPT_ASN_TALLYSHT_022                           */    
/* Creation Date: 31-OCT-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-21048 - BSJ Tally Sheet									      */    
/*                                                                      */    
/* Called By: RPT_ASN_TALLYSHT_022                                      */    
/*                                                                      */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver   Purposes                                  */
/* 04-NOV-2022  WZPang  1.0   DevOps Combine Script                     */
/* 01-FEB-2023  WZPang  1.1   Update SP                                 */
/* 27-JUL-2023  CSCHONG 1.2   WMS-23110 revised and add new field (CS01)*/
/************************************************************************/    
CREATE   PROC [dbo].[isp_RPT_ASN_TALLYSHT_022](    
            @c_Receiptkey     NVARCHAR(10)    
   )    
	AS      
 BEGIN      
    SET NOCOUNT ON      
    SET ANSI_NULLS OFF      
    SET QUOTED_IDENTIFIER OFF      
    SET CONCAT_NULL_YIELDS_NULL OFF      
    
	 DECLARE @Externkey NVARCHAR(10)        
    SELECT  @Externkey = externreceiptkey FROM Receipt WHERE receiptkey = @c_Receiptkey        
      
    CREATE TABLE #UCC (UCCNO nvarchar(20),ucount nvarchar(10))  
    INSERT INTO #UCC   
    SELECT userdefine01,ISNULL(CAST(COUNT(SKU) AS NVARCHAR),'') FROM RECEIPTDETAIL (NOLOCK) WHERE receiptkey = @c_Receiptkey  
    GROUP BY userdefine01  
   
    SELECT RECEIPT.ReceiptKey       
         , RECEIPT.ExternReceiptKey AS ExternReceiptkey          
         , RECEIPT.ReceiptDate AS ReceiptDate          
         , RECEIPT.Storerkey AS Storerkey        
         , RECEIPTDETAIL.userdefine01 AS UCCNo          
         --, CASE WHEN UCC.UCount is NULL then '-' else UCC.UCount END AS MixCarton          
         , CASE WHEN isnull(UCC.UCCNO,'')='' then '-' else UCC.UCount END AS MixCarton
         , RECEIPTDETAIL.SKU         
         , ISNULL(SKU.IVAS,'') AS IVAS         
         , RECEIPTDETAIL.QtyExpected AS  QtyExpected         
         , CASE WHEN RECEIPTDETAIL.QtyReceived ='0' THEN RECEIPTDETAIL.BeforeReceivedQty ELSE RECEIPTDETAIL.QtyReceived END AS QtyReceived          
         , CASE WHEN RECEIPTDETAIL.QtyReceived ='0' THEN RECEIPTDETAIL.BeforeReceivedQty ELSE RECEIPTDETAIL.QtyReceived END - RECEIPTDETAIL.QtyExpected AS VarianceQty    
         , '' AS TotalExpectedQty  
         , '' AS TotalQtyReceived  
         , '' AS TotalVarianceQty          
         , CASE WHEN RECEIPT.ProcessType = 'F' THEN 'Fully Inspection'   WHEN RECEIPT.ProcessType = 'P' Then 'Partial Inspection' ELSE '' END  AS ProcessType            
         , CODELKUP.Short        
         , RECEIPTDETAIL.ToId    
         , SUBSTRING(RECEIPT.WarehouseReference,1,10) AS WHREF01    --CS01
         , RECEIPT.Signatory             --CS01
         , SUBSTRING(RECEIPT.WarehouseReference,11,10) AS WHREF02   --CS01
    FROM RECEIPT (NOLOCK)              
    JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.Receiptkey)              
    JOIN SKU WITH (NOLOCK) ON (SKU.SKU = RECEIPTDETAIL.SKU and SKU.Storerkey = RECEIPT.Storerkey )              
    LEFT JOIN #UCC UCC WITH (NOLOCK) ON (UCC.UCCNO=RECEIPTDETAIL.UserDefine01)             
    LEFT JOIN CODELKUP WITH(NOLOCK) ON (CODELKUP.ListName = 'BSJPCate' AND CODELKUP.Long = SKU.skugroup             
            AND CODELKUP.Storerkey = RECEIPT.StorerKey)    
    WHERE Receipt.RECEIPTKEY = @c_Receiptkey        
   -- GROUP BY RECEIPT.ReceiptKey          
   --, RECEIPT.ExternReceiptKey          
   --, RECEIPT.ReceiptDate          
   --, RECEIPT.Storerkey         
   --, RECEIPTDETAIL.Sku          
   --, SKU.IVAS          
   --, RECEIPTDETAIL.QtyExpected      
   --, CASE WHEN RECEIPTDETAIL.QtyReceived ='0' THEN RECEIPTDETAIL.BeforeReceivedQty ELSE RECEIPTDETAIL.QtyReceived END       
   --, (CASE WHEN RECEIPTDETAIL.QtyReceived ='0' THEN RECEIPTDETAIL.BeforeReceivedQty ELSE RECEIPTDETAIL.QtyReceived END - RECEIPTDETAIL.QtyExpected )          
   --, CASE WHEN RECEIPT.ProcessType = 'F' THEN 'Fully Inspection' WHEN RECEIPT.ProcessType = 'P' Then 'Partial Inspection' ELSE '' END          
   --, CODELKUP.Short        
   --, RECEIPTDETAIL.ToId        
   --, RECEIPTDETAIL.userdefine01  
   --, UCC.UCount  
    ORDER BY SKU.IVAS,UCC.UCount,RECEIPTDETAIL.userdefine01, Sku         
   
END -- procedure      


GO