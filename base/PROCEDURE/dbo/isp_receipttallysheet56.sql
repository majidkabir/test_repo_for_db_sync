SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet56                            */
/* Creation Date: 30/11/2017                                            */
/* Copyright: IDS                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose: WMS-3513-REMY_Exceed_TallySheet                             */
/*                                                                      */
/* Called By: r_receipt_tallysheet56                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 19-AUG-2021  CSCHONG 1.1   WMS-17719 add new field (CS01)            */
/* 11-OCT-2021  CSCHONG 1.2   Devops Scripts combine                    */
/************************************************************************/
CREATE PROC [dbo].[isp_ReceiptTallySheet56] (
	   @c_receiptkeystart NVARCHAR(10),
	   @c_receiptkeyend   NVARCHAR(10),
	   @c_storerkeystart  NVARCHAR(15),
	   @c_storerkeyend    NVARCHAR(15)
   )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
								  
   SELECT (RTRIM(Storer.company) + RECEIPT.StorerKey) as storerkey,   
         RECEIPT.ContainerKey,   
         RECEIPT.Facility ,    
         RECEIPT.ReceiptDate,
         RECEIPT.ReceiptKey,   
         'PO' as PO,
         RECEIPT.POKey,   
         RECEIPTDETAIL.Lottable01,
         RTRIM(RECEIPTDETAIL.Sku) AS sku,   
         RECEIPTDETAIL.Lottable08,
         SKU.Descr,
         RECEIPTDETAIL.Lottable02,
         RECEIPTDETAIL.Lottable04,
         PACK.Casecnt, 
         CASE WHEN PACK.Casecnt = 0 THEN 1 ELSE CEILING(SUM(RECEIPTDETAIL.QtyExpected)/PACK.Casecnt) END AS QTYPERCASE,
         SUM(RECEIPTDETAIL.QtyExpected) AS QtyExpected,
         SKU.STDGROSSWGT as STDGROSSWGT,
         SKU.STDCUBE as STDCUBE,
         RECEIPT.CarrierReference AS CarrierReference          --CS01
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
   GROUP BY  (RTRIM(Storer.company) + RECEIPT.StorerKey),   
             RECEIPT.ContainerKey,   
             RECEIPT.Facility ,    
             RECEIPT.ReceiptDate,   
             RECEIPT.ReceiptKey, 
             RECEIPT.POKey,   
             RECEIPTDETAIL.Lottable01,
             RTRIM(RECEIPTDETAIL.Sku),   
             RECEIPTDETAIL.Lottable08,
             SKU.Descr,
             RECEIPTDETAIL.Lottable02,
             RECEIPTDETAIL.Lottable04,
             PACK.Casecnt, 
             RECEIPTDETAIL.QtyExpected,
             SKU.STDGROSSWGT,
             SKU.STDCUBE,receipt.CarrierReference
   ORDER BY RECEIPT.ReceiptKey, RTRIM(RECEIPTDETAIL.Sku)
   
END        

GO