SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Stored Procedure: isp_RPT_ASN_RCPDETMTX_002_1                        */          
/* Creation Date: 2-AUG-2022                                            */      
/* Copyright: LF Logistics                                              */      
/* Written by: WZPang                                                   */      
/*                                                                      */      
/* Purpose: Convert to Logi Report - r_dw_receiving_matrix_us03  (TH)   */        
/*                                                                      */          
/* Called By: RPT_ASN_RCPDETMTX_002_1                */          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 7.0                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author   Ver  Purposes                                  */  
/* 2-AUG-2022  WZPang   1.0  DevOps Combine Script                     */       
/************************************************************************/          
CREATE PROC [dbo].[isp_RPT_ASN_RCPDETMTX_002_1] (  
      @c_receiptkey        NVARCHAR(10),  
      @c_Style             NVARCHAR(10),  
      @c_Color             NVARCHAR(10),  
      @c_Lottable02        NVARCHAR(30)  
)          
 AS          
 BEGIN          
              
   SET NOCOUNT ON          
   SET ANSI_NULLS ON          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF          
   SET ANSI_WARNINGS ON          
      
    SELECT SKU.BUSR8,  
  sku.size,   
  rowd = '',   
      QtyExpected = SUM (RD.QtyExpected),    
  QtyReceived = SUM( RD.QtyReceived)   
   FROM Receipt WITH (NOLOCK)   
  JOIN ReceiptDetail RD WITH (NOLOCK) on ( RD.StorerKey = Receipt.StorerKey AND RD.ReceiptKey = Receipt.ReceiptKey )   
  LEFT JOIN SKU WITH (NOLOCK) on ( SKU.StorerKey = RD.StorerKey AND SKU.SKU = RD.SKU )   
   Where Receipt.Receiptkey = @c_receiptkey   
    AND SKU.style  = @c_style   
    AND SKU.color  = @c_color   
    AND RD.lottable02  = @c_lottable02   
   GROUP BY SKU.BUSR8, sku.size   
   ORDER BY SKU.BUSR8  
        
END -- procedure      

GO