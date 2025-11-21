SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Procedure: isp_RPT_ASN_TALLYSHT_021                           */        
/* Creation Date: 19-SEP-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: Create New Report - WMS-20700                               */      
/*                                                                      */        
/* Called By: RPT_ASN_TALLYSHT_021										*/        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_ASN_TALLYSHT_021] (
      @c_receiptkey        NVARCHAR(10)  
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        
    
   --declare @parm_receiptkey varchar(10) = '0000309245'

   SELECT 
	a.ReceiptKey
	, a.ExternReceiptKey
	, b.ExternPoKey
	, a.Notes
	, a.OriginCountry [COO]
	, c.SKUGROUP [Division]
	, c.Style [Article]
	, b.Sku
	, c.DESCR
	, c.Size
	, SUM(b.QtyExpected) [Qty]
   --	, d.SKUCount
	, DENSE_RANK() OVER (ORDER BY b.Sku )  + DENSE_RANK() OVER (ORDER BY b.sku DESC) - 1 [SKUCount]
	, SUM(SUM(b.QtyExpected)) OVER (PARTITION BY a.ReceiptKey) [TotalQty]
    , Userid = SUSER_SNAME()
	, a.ContainerKey
   FROM V_RECEIPT a
   JOIN V_RECEIPTDETAIL b ON a.ReceiptKey = b.ReceiptKey
   JOIN V_SKU c ON b.StorerKey = c.StorerKey and b.Sku = c.Sku
   --cross apply (select count(distinct SKU) [SKUCount] from V_RECEIPTDETAIL where ReceiptKey = a.ReceiptKey) d
   WHERE 
   	a.ReceiptKey = @c_ReceiptKey
   GROUP BY
	a.ReceiptKey
	, a.ExternReceiptKey
	, b.ExternPoKey
	, a.Notes
	, a.OriginCountry --[COO]
	, c.SKUGROUP --[Division]
	, c.Style --[Article]
	, b.Sku
	, c.DESCR
	, c.Size
	, a.ContainerKey
   ORDER BY b.Sku    
  
  
   
END -- procedure    

GO