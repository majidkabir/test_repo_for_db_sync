SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet54      					         */
/* Creation Date: 23/05/2017                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1969-CNWMS-DYSON_Exceed_TallySheet                      */
/*                                                                      */
/* Called By: r_receipt_tallysheet54                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/*14-Feb-2020   WLChooi 1.1   WMS-12074 - Add New Column (WL01)         */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet54] (
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
                  
                
   SELECT RECEIPT.ReceiptKey,   
         RECEIPT.ExternReceiptkey,   
         RECEIPTDETAIL.Sku ,    
         SKU.DESCR,   
         RECEIPT.Facility,   
         RECEIPT.Carrierreference as UserDefine03,   
         RECEIPT.RecType,   
         RECEIPT.ContainerKey,   
         RECEIPT.ReceiptDate,   
         SUM(RECEIPTDETAIL.QtyExpected) AS QtyExpected ,
			PACK.Casecnt,
			PACK.Pallet,
			SKU.BUSR1,
         RECEIPT.Userdefine03   --WL01
    FROM RECEIPT WITH (NOLOCK) 
	 JOIN RECEIPTDETAIL WITH (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey ) 
    JOIN SKU WITH (NOLOCK) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey 
         					  AND SKU.Sku = RECEIPTDETAIL.Sku )
    JOIN STORER WITH (NOLOCK) ON ( RECEIPT.Storerkey = STORER.Storerkey ) 
	 JOIN PACK WITH (NOLOCK) ON ( SKU.Packkey = PACK.Packkey ) 
   WHERE ( RECEIPT.ReceiptKey >= @c_receiptkeystart ) 
	  AND ( RECEIPT.ReceiptKey <= @c_receiptkeyend ) 
	  AND ( RECEIPT.Storerkey >= @c_storerkeystart ) 
	  AND ( RECEIPT.Storerkey <= @c_storerkeyend ) 
   GROUP BY RECEIPT.ReceiptKey,   
         RECEIPT.ExternReceiptkey,   
         RECEIPTDETAIL.Sku ,    
         SKU.DESCR,   
         RECEIPT.Facility,   
         RECEIPT.Carrierreference,   
         RECEIPT.RecType,   
         RECEIPT.ContainerKey,   
         RECEIPT.ReceiptDate,   
			PACK.Casecnt,
			PACK.Pallet,
			SKU.BUSR1,
         RECEIPT.Userdefine03   --WL01
   ORDER BY RECEIPT.ReceiptKey,RECEIPTDETAIL.Sku
 END        


GO