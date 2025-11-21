SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nsp_putaway_summary_02] (
  @Receiptkey_start     NVARCHAR(10),
  @Receiptkey_end   	 NVARCHAR(10)
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

  SELECT RECEIPT.ReceiptKey,   
         dbo.fnc_LTrim(dbo.fnc_RTrim(SKU.BUSR7)) + '-' +
         LEFT(SKU.SKU, 6) + '-' + 
         SUBSTRING(SKU.SKU, 7, 3) + '-' + 
         SUBSTRING(SKU.SKU, 10, 2) + '-' +
         SUBSTRING(SKU.SKU, 12, 2) + '-' + 
         SUBSTRING(SKU.SKU, 14, 2) + '-' + 
         SUBSTRING(SKU.SKU, 16, 5) AS Sku,     
         SKU.DESCR,   
         RECEIPTDETAIL.QtyExpected,   
         RECEIPTDETAIL.QtyReceived, 
         (RECEIPTDETAIL.QtyReceived - RECEIPTDETAIL.QtyExpected) as Variance,
         PO.ExternPOKey,
         PODETAIL.Userdefine01 ,
         RECEIPT.Carriername  
    INTO #TEMPSUM
    FROM RECEIPT (NOLOCK)
         JOIN RECEIPTDETAIL (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey  and  
                                          RECEIPT.Storerkey = RECEIPTDETAIL.Storerkey )    
         JOIN SKU (NOLOCK) ON ( SKU.StorerKey = RECEIPT.StorerKey and  
                                SKU.Sku = RECEIPTDETAIL.Sku ) 
         LEFT OUTER JOIN PO (NOLOCK) ON ( PO.POKey = RECEIPTDETAIL.POKey AND PO.Storerkey = RECEIPT.Storerkey ) 
         LEFT OUTER JOIN PODETAIL (NOLOCK) ON ( PO.POKey = PODETAIL.POKey AND RECEIPTDETAIL.Sku = PODETAIL.Sku AND
                                                PODETAIL.POLinenumber = RECEIPTDETAIL.POLinenumber) 
   WHERE ( RECEIPT.ReceiptKey >= @Receiptkey_start) AND  
         ( RECEIPT.ReceiptKey <= @Receiptkey_end)

   SELECT Receiptkey, 
          Sku,   
          DESCR,   
          SUM(QtyExpected) as TotalExpected,   
          SUM(QtyReceived) as TotalReceived, 
          SUM(Variance) as Variance,
          ExternPOKey,
          Userdefine01 ,
          Carriername  
    FROM #TEMPSUM  
    GROUP BY Receiptkey, 
             Sku,   
             DESCR,   
             ExternPOKey,
             Userdefine01 ,
             Carriername  

END -- Procedure

GO