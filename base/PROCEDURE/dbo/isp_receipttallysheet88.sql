SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet88    					         */
/* Creation Date: 12/12/2022                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-21245                                                   */
/*                                                                      */
/* Called By: r_receipt_tallysheet88                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 12/12/2022   MINGLE  1.0   DevOps Combine Script(Created-WMS-21245)  */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet88] (
   @c_receiptkeystart NVARCHAR(10),
   @c_receiptkeyend NVARCHAR(10),
   @c_storerkeystart NVARCHAR(15),
   @c_storerkeyend NVARCHAR(15),
	@c_username NVARCHAR(30)  
   )
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF	     


	 
	 SELECT RECEIPT.ReceiptKey,   
         RECEIPTDETAIL.POKey,   
         RECEIPTDETAIL.Sku,   
         SKU.DESCR,   
         RECEIPTDETAIL.UOM,   
         RECEIPTDETAIL.Lottable02,   
         RECEIPTDETAIL.Lottable04,   
         STORER.Company,   
         RECEIPT.ReceiptDate,   
         RECEIPTDETAIL.PackKey,   
         SKU.SUSR3,   
         RECEIPTDETAIL.QtyExpected , 
			RECEIPTDETAIL.BeforeReceivedQty,
			CASE WHEN ISNULL(@c_username,'') <> '' THEN @c_username ELSE (SUSER_NAME()) END AS USERNAME,         
			(RECEIPTDETAIL.QtyExpected/NULLIF(Pack.innerpack,0)) AS INNERQty,
         ISNULL(CL.Short,'0') AS 'SHOWUOM2QTY',
			CASE WHEN RECEIPTDETAIL.PackKey='PK30' THEN (RECEIPTDETAIL.QtyExpected/30) 
              WHEN RECEIPTDETAIL.PackKey='PK6' THEN (RECEIPTDETAIL.QtyExpected/6) 
              ELSE 0 END AS PACKQTY,
			ISNULL(CL1.Short,'0') AS 'SHOWPACKQTY',
			ISNULL(CL2.Short,'0') AS 'SORTBYRECLINE'
     FROM RECEIPT (NOLOCK)   
	  JOIN RECEIPTDETAIL (NOLOCK) ON  ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey )
     JOIN SKU (NOLOCK) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey )  
     JOIN STORER (NOLOCK) ON ( SKU.Sku = RECEIPTDETAIL.Sku ) 
                         AND ( RECEIPT.Storerkey = STORER.Storerkey ) 
     JOIN PACK (NOLOCK) ON (SKU.Packkey = Pack.Packkey) 
     LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName = 'REPORTCFG' AND CL.Long = 'r_receipt_tallysheet88'
                                        AND CL.Code = 'SHOWUOM2QTY' AND CL.Storerkey = STORER.StorerKey  
     LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.ListName = 'REPORTCFG' AND CL1.Long = 'r_receipt_tallysheet88'
                                        AND CL1.Code = 'SHOWPACKQTY' AND CL1.Storerkey = STORER.StorerKey
	  LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.ListName = 'REPORTCFG' AND CL2.Long = 'r_receipt_tallysheet88'
                                         AND CL2.Code = 'SORTBYRECLINE' AND CL2.Storerkey = STORER.StorerKey   
     WHERE ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey ) AND  
         ( SKU.StorerKey = RECEIPTDETAIL.StorerKey ) AND  
         ( SKU.Sku = RECEIPTDETAIL.Sku ) and  
         ( RECEIPT.Storerkey = STORER.Storerkey ) AND 
         ( RECEIPT.ReceiptKey >= @c_receiptkeystart ) AND  
         ( RECEIPT.ReceiptKey <= @c_receiptkeyend ) AND  
         ( RECEIPT.Storerkey >= @c_storerkeystart ) AND 
         ( RECEIPT.Storerkey <= @c_storerkeyend ) 
	  ORDER BY CASE WHEN ISNULL(CL2.Short,'0') = 'Y' THEN  RECEIPTDETAIL.ExternLineNo  END ASC,RECEIPTDETAIL.Sku

                              
END

GO