SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet38    								        */
/* Creation Date: 03/09/2013                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#288535                                                  */
/*                                                                      */
/* Called By: r_receipt_tallysheet38                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet38] (
   @c_receiptkeystart NVARCHAR(10),
   @c_receiptkeyend NVARCHAR(10),
   @c_storerkeystart NVARCHAR(15),
   @c_storerkeyend NVARCHAR(15)
   )
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @c_OtherReferenceALL NVARCHAR(250),
            @c_SellerNameALL NVARCHAR(250),
            @c_SellerAddress1ALL NVARCHAR(250),
            @c_OtherReference NVARCHAR(18),
            @c_SellerName NVARCHAR(45),
            @c_SellerAddress1 NVARCHAR(45),
            @c_Receiptkey NVARCHAR(10),
            @c_PrevReceiptkey NVARCHAR(10)
            
    SELECT RECEIPT.Storerkey,
           RECEIPT.Facility,
           RECEIPT.Receiptkey,
           CASE WHEN RECEIPT.DocType='A' THEN 'NORMAL'
                WHEN RECEIPT.DocType='R' THEN 'RTN'
           ELSE RECEIPT.Doctype END AS DocType,
           RECEIPT.Carrierkey,
           CONVERT(NVARCHAR(250),'') AS OtherReference,
           CONVERT(NVARCHAR(250),'') AS SellerName,
           CONVERT(NVARCHAR(250),'') AS SellerAddress1,
           Receipt.editdate AS RecDate,
           PO.ExternPokey,
           UCC.UCCNo,
           COUNT(DISTINCT UCC.Sku) AS skucnt
    INTO #TMP_REC
    FROM RECEIPT (NOLOCK)
    JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
    LEFT JOIN PO (NOLOCK) ON RECEIPTDETAIL.ExternReceiptkey = PO.ExternPokey
    LEFT JOIN UCC (NOLOCK) ON RECEIPTDETAIL.ExternReceiptkey = UCC.Externkey AND RECEIPT.Storerkey = UCC.Storerkey AND ISNULL(UCC.Externkey,'') <> ''  
    WHERE RECEIPT.Storerkey BETWEEN @c_storerkeystart AND @c_storerkeyend 
    AND RECEIPT.Receiptkey BETWEEN @c_receiptkeystart AND @c_receiptkeyend
    GROUP BY RECEIPT.Storerkey,
             RECEIPT.Facility,
             RECEIPT.Receiptkey,
             CASE WHEN RECEIPT.DocType='A' THEN 'NORMAL'
                  WHEN RECEIPT.DocType='R' THEN 'RTN'
             ELSE RECEIPT.Doctype END,
             RECEIPT.Carrierkey,
             Receipt.editdate,
             PO.ExternPokey,
             UCC.UCCNo
    
    SET @c_PrevReceiptkey  = ''
    DECLARE REC_CUR CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT RECEIPT.RECEIPTKEY, PO.OtherReference, PO.SellerName, PO.SellerAddress1
       FROM RECEIPT (NOLOCK)
       JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
       JOIN PO (NOLOCK) ON RECEIPTDETAIL.ExternReceiptkey = PO.ExternPokey
       WHERE RECEIPT.Storerkey BETWEEN @c_storerkeystart AND @c_storerkeyend        
       AND RECEIPT.Receiptkey BETWEEN @c_receiptkeystart AND @c_receiptkeyend
       ORDER BY RECEIPT.Receiptkey, PO.OtherReference, PO.SellerName, PO.SellerAddress1
           
    OPEN REC_CUR  
                      
    FETCH NEXT FROM REC_CUR INTO @c_Receiptkey, @c_OtherReference, @c_SellerName, @c_SellerAddress1 
                      	           
	  SELECT @c_PrevReceiptkey = ''
	  WHILE @@FETCH_STATUS <> -1                       	               
	  BEGIN
	  	 IF @c_Receiptkey <> @c_PrevReceiptkey
	  	 BEGIN	  	 	  
	  	 	  SELECT @c_OtherReferenceALL = RTRIM(ISNULL(@c_OtherReference,''))
	  	 	  SELECT @c_SellerNameALL = RTRIM(ISNULL(@c_SellerName,''))
	  	 	  SELECT @c_SellerAddress1ALL = RTRIM(ISNULL(@c_SellerAddress1,''))
	  	 END
	  	 ELSE
	  	 BEGIN
	  	   	SELECT @c_OtherReferenceALL = @c_OtherReferenceALL + CASE WHEN LEN(@c_OtherReferenceALL) > 0  THEN ' / ' ELSE '' END + RTRIM(ISNULL(@c_OtherReference,''))
	  	 	  SELECT @c_SellerNameALL = @c_SellerNameALL + CASE WHEN LEN(@c_SellerNameALL) > 0  THEN ' / ' ELSE '' END + RTRIM(ISNULL(@c_SellerName,''))
	  	 	  SELECT @c_SellerAddress1ALL = @c_SellerAddress1ALL + CASE WHEN LEN(@c_SellerAddress1ALL) > 0  THEN ' / ' ELSE '' END + RTRIM(ISNULL(@c_SellerAddress1,''))
	  	 END
	  	 
	  	 SELECT @c_PrevReceiptkey = @c_Receiptkey
	  	                      
       FETCH NEXT FROM REC_CUR INTO @c_Receiptkey, @c_OtherReference, @c_SellerName, @c_SellerAddress1 
       
       IF @c_Receiptkey <> @c_PrevReceiptkey OR @@FETCH_STATUS = -1 
       BEGIN
       	  UPDATE #TMP_REC
       	  SET OtherReference = @c_OtherReferenceALL,
       	      SellerName = @c_SellerNameALL,
       	      SellerAddress1 = @c_SellerAddress1ALL
       	  WHERE Receiptkey = @c_PrevReceiptkey
       END
	  END
	  CLOSE REC_CUR
	  DEALLOCATE REC_CUR
	  	                                           	               
    --- Normal ASN UCC with single SKU
    SELECT #TMP_REC.Storerkey,
           #TMP_REC.Facility,
           #TMP_REC.Receiptkey,
           #TMP_REC.DocType,
           #TMP_REC.Carrierkey,
           #TMP_REC.OtherReference,
           #TMP_REC.SellerName,
           #TMP_REC.SellerAddress1,
           #TMP_REC.RecDate,
           #TMP_REC.ExternPokey,
           '' AS UCCNo,
           'Single SKU' AS UCCtype,   
           UCC.Sku,   
           SKU.Size,         
           UCC.Qty AS UCCQty,
           COUNT(DISTINCT UCC.UCCNO) AS QTYCT,
           COUNT(DISTINCT UCC.UCCNO) * UCC.Qty AS Qty
    INTO #TMP_NORMAL_SINGLESKU
    FROM #TMP_REC
    JOIN UCC (NOLOCK) ON #TMP_REC.UCCno = UCC.UCCNo
    JOIN SKU (NOLOCK) ON UCC.Storerkey = SKU.Storerkey AND UCC.Sku = SKU.Sku 
    WHERE #TMP_REC.DocType = 'NORMAL'
    AND #TMP_REC.Skucnt = 1    
    GROUP BY #TMP_REC.Storerkey,
             #TMP_REC.Facility,
             #TMP_REC.Receiptkey,
             #TMP_REC.DocType,
             #TMP_REC.Carrierkey,
             #TMP_REC.OtherReference,
             #TMP_REC.SellerName,
             #TMP_REC.SellerAddress1,
             #TMP_REC.RecDate,
             #TMP_REC.ExternPokey,
             UCC.Sku,   
             SKU.Size,
             UCC.Qty          
    
    --- Normal ASN UCC with mix sku
    SELECT #TMP_REC.Storerkey,
           #TMP_REC.Facility,
           #TMP_REC.Receiptkey,
           #TMP_REC.DocType,
           #TMP_REC.Carrierkey,
           #TMP_REC.OtherReference,
           #TMP_REC.SellerName,
           #TMP_REC.SellerAddress1,
           #TMP_REC.RecDate,
           #TMP_REC.ExternPokey,
           UCC.UccNo,
           'Mix SKU' AS UCCtype,   
           UCC.Sku,   
           SKU.Size,         
           UCC.Qty AS UCCQty,
           1 AS QTYCT,       
           UCC.Qty AS Qty                                  
    INTO #TMP_NORMAL_MIXSKU
    FROM #TMP_REC
    JOIN UCC (NOLOCK) ON #TMP_REC.UCCno = UCC.UCCNo
    JOIN SKU (NOLOCK) ON UCC.Storerkey = SKU.Storerkey AND UCC.Sku = SKU.Sku 
    WHERE #TMP_REC.DocType = 'NORMAL'
    AND #TMP_REC.Skucnt > 1    
    GROUP BY #TMP_REC.Storerkey,
             #TMP_REC.Facility,
             #TMP_REC.Receiptkey,
             #TMP_REC.DocType,
             #TMP_REC.Carrierkey,
             #TMP_REC.OtherReference,
             #TMP_REC.SellerName,
             #TMP_REC.SellerAddress1,
             #TMP_REC.RecDate,
             #TMP_REC.ExternPokey,
             UCC.UccNo,
             UCC.Sku,   
             SKU.Size,
             UCC.Qty                        
    
    --- Return ASN Without UCC
    SELECT TR.Storerkey,
           TR.Facility,
           TR.Receiptkey,
           TR.DocType,
           TR.Carrierkey,
           TR.OtherReference,
           TR.SellerName,
           TR.SellerAddress1,
           TR.RecDate,
           RECEIPTDETAIL.ExternReceiptkey AS ExternPokey,
           '' AS UccNo,
           '' AS UCCtype,   
           RECEIPTDETAIL.Sku,   
           SKU.Size,         
           0 AS UCCQty,
           0 AS QTYCT ,
           SUM(RECEIPTDETAIL.Qtyexpected) AS Qty
    INTO #TMP_RETURN
    FROM (SELECT DISTINCT #TMP_REC.Storerkey,      
                 #TMP_REC.Facility,       
                 #TMP_REC.Receiptkey,     
                 #TMP_REC.DocType,        
                 #TMP_REC.Carrierkey,     
                 #TMP_REC.OtherReference, 
                 #TMP_REC.SellerName,     
                 #TMP_REC.SellerAddress1, 
                 #TMP_REC.RecDate       
          FROM #TMP_REC) AS TR
    JOIN RECEIPTDETAIL (NOLOCK) ON TR.Receiptkey = RECEIPTDETAIL.Receiptkey
    JOIN SKU (NOLOCK) ON RECEIPTDETAIL.Storerkey = SKU.Storerkey AND RECEIPTDETAIL.Sku = SKU.Sku 
    WHERE TR.DocType = 'RTN'
    GROUP BY TR.Storerkey,
             TR.Facility,
             TR.Receiptkey,
             TR.DocType,
             TR.Carrierkey,
             TR.OtherReference,
             TR.SellerName,
             TR.SellerAddress1,
             TR.RecDate,
             RECEIPTDETAIL.ExternReceiptkey, 
             RECEIPTDETAIL.Sku,                            
             SKU.Size            
    
    SELECT * 
    FROM #TMP_NORMAL_SINGLESKU
    UNION
    SELECT * 
    FROM #TMP_NORMAL_MIXSKU
    UNION
    SELECT * 
    FROM #TMP_RETURN                      
 END        

GO