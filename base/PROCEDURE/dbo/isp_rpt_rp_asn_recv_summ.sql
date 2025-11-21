SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Stored Procedure: ISP_RPT_RP_ASN_RECV_SUMM                              */      
/* Creation Date: 27-APR-2023                                              */      
/* Copyright: LFL                                                          */      
/* Written by: CSCHONG                                                     */      
/*                                                                         */      
/* Purpose: WMS-22427                                                      */      
/*                                                                         */      
/* Called By: RPT_RP_ASN_RECV_SUMM                                         */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date            Author          Ver     Purposes                        */  
/* 27-APR-2023     CSCHONG         1.0     Devops Scripts Combine          */
/***************************************************************************/   
  
CREATE    PROC [dbo].[ISP_RPT_RP_ASN_RECV_SUMM]  
     @c_Storerkey                  NVARCHAR(20)  
    ,@c_Facility                   NVARCHAR(20)
    ,@c_SellerPhone1               NVARCHAR(45)
    ,@c_SellerPhone2               NVARCHAR(45)
       
AS    
BEGIN  
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

 DECLARE   @c_DataWindow  NVARCHAR(60) = 'RPT_RP_ASN_RECV_SUMM'    
         , @c_RetVal      NVARCHAR(255)  
         , @c_Type        NVARCHAR(1) = '1'  
         , @n_TTLQtyRecv  INT 
         , @n_TTLQtyExp   INT

   SET @c_RetVal = ''    
  
    
         IF ISNULL(@c_Storerkey,'') <> ''    
         BEGIN    
    
         EXEC [dbo].[isp_GetCompanyInfo]    
                  @c_Storerkey  = @c_Storerkey    
               ,  @c_Type       = @c_Type    
               ,  @c_DataWindow = @c_DataWindow    
               ,  @c_RetVal     = @c_RetVal           OUTPUT    
     
         END     


   SELECT  @n_TTLQtyRecv = SUM(RECEIPTDETAIL.QtyReceived)
          ,@n_TTLQtyExp = SUM(RECEIPTDETAIL.QtyExpected)
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK)  ON  ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey ) 
   WHERE RECEIPT.storerkey = @c_Storerkey AND RECEIPT.facility = @c_Facility 
   AND RECEIPT.Sellerphone1 = @c_SellerPhone1 AND RECEIPT.Sellerphone2 = @c_SellerPhone2    
  
   SELECT  RECEIPTDETAIL.Sku,     
           RECEIPTDETAIL.QtyReceived,     
           MAX(RECEIPTDETAIL.EditDate) AS EditDate,  
           RECEIPT.Storerkey,  
           RECEIPT.SellerCompany,  
           RECEIPT.Sellerphone1,  
           RECEIPT.Sellerphone2,  
           RECEIPTDETAIL.UOM,  
           RECEIPT.ReceiptKey,  
           RECEIPT.ExternReceiptKey,  
           RECEIPTDETAIL.QtyExpected,     
           SKU.DESCR,     
           RECEIPTDETAIL.Lottable01,     
           RECEIPTDETAIL.Lottable02,
           ISNULL(@c_Retval,'')    AS Logo,
           @n_TTLQtyRecv AS TTLQTYRCV,@n_TTLQtyExp AS TTLQTYEXP    
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK)  ON  ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey ) 
   JOIN SKU (NOLOCK) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey ) and  ( SKU.Sku = RECEIPTDETAIL.Sku )    
   WHERE RECEIPT.storerkey = @c_Storerkey AND RECEIPT.facility = @c_Facility 
   AND RECEIPT.Sellerphone1 = @c_SellerPhone1 AND RECEIPT.Sellerphone2 = @c_SellerPhone2    
   GROUP BY  RECEIPTDETAIL.Sku,     
             RECEIPTDETAIL.QtyReceived,     
             --RECEIPTDETAIL.EditDate,  
             RECEIPT.Storerkey,  
             RECEIPT.SellerCompany,     
             RECEIPT.Sellerphone1,  
             RECEIPT.Sellerphone2,  
             RECEIPTDETAIL.UOM,  
             RECEIPT.ReceiptKey,  
             RECEIPT.ExternReceiptKey,  
             RECEIPTDETAIL.QtyExpected,     
             SKU.DESCR,     
             RECEIPTDETAIL.Lottable01,     
             RECEIPTDETAIL.Lottable02
             ORDER BY RECEIPT.storerkey ,RECEIPT.Sellerphone1,RECEIPT.Sellerphone2,RECEIPT.ReceiptKey,RECEIPT.ExternReceiptKey
  
END        

SET QUOTED_IDENTIFIER OFF 

GO