SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet82                            */
/* Creation Date: 2021-08-04                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17610 - MOSAIC Tally Sheet                              */
/*                                                                      */
/* Called By: r_receipt_tallysheet82                                    */
/*            Copy and modify from r_receipt_tallysheet02               */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet82] (
   @c_ReceiptkeyStart NVARCHAR(10),
   @c_ReceiptkeyEnd   NVARCHAR(10),
   @c_StorerkeyStart  NVARCHAR(15),
   @c_StorerkeyEnd    NVARCHAR(15)
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
          SUM(RECEIPTDETAIL.QtyExpected) AS QtyExpected, 
          SUM(RECEIPTDETAIL.BeforeReceivedQty) AS BeforeReceivedQty,
          SUSER_SNAME(),         
          (SUM(RECEIPTDETAIL.QtyExpected)/NULLIF(Pack.innerpack,0)) as INNERQty,
          ISNULL(CL.Short,'0') as 'SHOWUOM2QTY',
          CASE WHEN RECEIPTDETAIL.PackKey='PK30' THEN (SUM(RECEIPTDETAIL.QtyExpected)/30) 
               WHEN RECEIPTDETAIL.PackKey='PK6' THEN (SUM(RECEIPTDETAIL.QtyExpected)/6) 
               ELSE 0 END AS PACKQTY,
          ISNULL(CL1.Short,'0') as 'SHOWPACKQTY',
          ISNULL(CL2.Short,'0') as 'SORTBYRECLINE',
          RECEIPT.ExternReceiptKey,
          ISNULL(SKU.[Length],0.00) * ISNULL(SKU.[Width],0.00) * ISNULL(SKU.[Height],0.00) AS LXWXH,
          ISNULL(SKU.[Weight],0.00) AS SKUWeight,
          ISNULL(SKU.NOTES1,'') AS SKUNotes1,
          ISNULL(SKU.CLASS,'') AS SKUClass
   FROM RECEIPT (nolock)   
   JOIN RECEIPTDETAIL (nolock) ON  ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey )
   JOIN SKU (nolock) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku )  
   JOIN STORER (nolock) ON (RECEIPT.Storerkey = STORER.Storerkey ) 
   JOIN PACK (nolock) ON (SKU.Packkey = Pack.Packkey) 
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName = 'REPORTCFG' AND CL.Long = 'r_receipt_tallysheet82'
                                      AND CL.Code = 'SHOWUOM2QTY' AND CL.Storerkey = STORER.StorerKey  
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.ListName = 'REPORTCFG' AND CL1.Long = 'r_receipt_tallysheet82'
                                      AND CL1.Code = 'SHOWPACKQTY' AND CL1.Storerkey = STORER.StorerKey
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.ListName = 'REPORTCFG' AND CL2.Long = 'r_receipt_tallysheet82'
                                      AND CL2.Code = 'SORTBYRECLINE' AND CL2.Storerkey = STORER.StorerKey  
   --CROSS APPLY (SELECT TOP 1 PODETAIL.ExternPOKey 
   --             FROM PODETAIL (NOLOCK) 
   --             WHERE PODETAIL.ExternPOKey = RECEIPT.ExternReceiptKey  
   --               AND PODETAIL.StorerKey = RECEIPT.StorerKey) AS PODET
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptkeyStart ) AND  
         ( RECEIPT.ReceiptKey <= @c_ReceiptkeyEnd ) AND  
         ( RECEIPT.Storerkey >= @c_StorerkeyStart ) AND 
         ( RECEIPT.Storerkey <= @c_StorerkeyEnd ) 
   GROUP BY RECEIPT.ReceiptKey,   
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
            ISNULL(CL1.Short,'0'),
            ISNULL(CL2.Short,'0'),
            RECEIPT.ExternReceiptKey,
            ISNULL(SKU.[Length],0.00) * ISNULL(SKU.[Width],0.00) * ISNULL(SKU.[Height],0.00),
            ISNULL(SKU.[Weight],0.00),
            ISNULL(SKU.NOTES1,''),
            ISNULL(SKU.CLASS,''),
            Pack.innerpack,
            ISNULL(CL.Short,'0'),
            CASE WHEN ISNULL(CL2.Short,'0') = 'Y' THEN RECEIPTDETAIL.ExternLineNo END
   ORDER BY CASE WHEN ISNULL(CL2.Short,'0') = 'Y' THEN RECEIPTDETAIL.ExternLineNo END ASC,
            RECEIPTDETAIL.Sku
   
END        

GO