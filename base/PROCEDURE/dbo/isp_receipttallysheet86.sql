SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptTallySheet86                                 */  
/* Creation Date: 05-Aug-2022                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: mingle(copy from isp_ReceiptTallySheet77)                */  
/*                                                                      */  
/* Purpose: WMS-20351 - SG - IDSMED - Tally Sheet Barcode and signature */   
/*                      changes                                         */  
/* Called By: r_receipt_tallysheet86                                    */
/*          :                                                           */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 05/08/2022   Mingle    1.0 DevOps Combine Script(Created)            */ 
/* 06-Jan-2023  WLChooi   1.1 WMS-21469 - Add Lottable06 (WL01)         */
/************************************************************************/ 

CREATE PROC [dbo].[isp_ReceiptTallySheet86]  
            @c_ReceiptKeyStart   NVARCHAR(10)  
         ,  @c_ReceiptKeyEnd     NVARCHAR(10)  
         ,  @c_StorerKeyStart    NVARCHAR(15)  
         ,  @c_StorerKeyEnd      NVARCHAR(15) 
         ,  @c_userid            NVARCHAR(20) = ''
  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @n_continue INT = 1, @n_err INT = 0, @c_errmsg NVARCHAR(255) = '', @b_Success INT = 1
   DECLARE @n_StartTCnt INT = @@TRANCOUNT
             
   SELECT STORER.Company,        
          RECEIPT.ReceiptKey,   
          RECEIPT.CarrierReference,   
          RECEIPT.StorerKey,   
          RECEIPT.CarrierName,
          PO.SellerName,   
          RECEIPT.ReceiptDate,   
          RECEIPTDETAIL.Sku,   
          RECEIPTDETAIL.Lottable02 as receiptdetail_lottable02,   
          SKU.DESCR,   
          RECEIPTDETAIL.Lottable04,   
          RECEIPTDETAIL.UOM,   
          SUM(RECEIPTDETAIL.QtyExpected) AS QtyExp,   
          SUM(RECEIPTDETAIL.QtyExpected / nullif(CASE RECEIPTDETAIL.UOM
             WHEN PACK.PACKUOM1 THEN PACK.CaseCnt
             WHEN PACK.PACKUOM2 THEN PACK.InnerPack
             WHEN PACK.PACKUOM3 THEN 1
             WHEN PACK.PACKUOM4 THEN PACK.Pallet
             WHEN PACK.PACKUOM5 THEN PACK.Cube
             WHEN PACK.PACKUOM6 THEN PACK.GrossWgt
             WHEN PACK.PACKUOM7 THEN PACK.NetWgt
             WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1
             WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2
             END,0)) AS RECQtyExp, 
         RECEIPT.CarrierAddress1,
         RECEIPT.POkey,
         PACK.CaseCnt,
         RECEIPTDETAIL.Lottable03,
         RECEIPT.Signatory,
         RECEIPT.Userdefine01,
         RECEIPT.Facility,
         RECEIPTDETAIL.lottable01,
         RECEIPT.Containerkey,
         RECEIPT.containertype,
         RECEIPTDETAIL.ReceiptLinenumber,
         SKU.RetailSku,
         SKU.AltSku,
         SKU.ManufacturerSku,
         CONVERT(CHAR(20),@c_userid) AS userid,      
         RECEIPT.ExternReceiptKey,
         SKU.SUSR3,
         SKU.SUSR4,
         SKU.Shelflife,
         convert(nvarchar(10),DATEADD(DAY,SKU.Shelflife,RECEIPT.ReceiptDate),101) As ExpDate,
         ISNULL(SKU.IVAS,'') AS IVAS,
         RECEIPTDETAIL.Lottable09,
         RECEIPT.notes, 
         SKU.Lottable02label,
         --START (ML01)
         RECEIPTDETAIL.Lottable12,
         RECEIPTDETAIL.Lottable08,
         RECEIPTDETAIL.Lottable10,
         RECEIPTDETAIL.Lottable11,
         RECEIPTDETAIL.ExternPOKey,
         RECEIPTDETAIL.Userdefine02,
         SKUGroup = CASE WHEN RECEIPTDETAIL.StorerKey = 'IDSMED' THEN SKU.SKUGroup ELSE '' END,
         --END (ML01)
         RECEIPTDETAIL.toloc,    
         ISNULL(CL.SHORT,'') as ShowToLoc,
         ISNULL(RECEIPTDETAIL.Lottable06,'') AS Lottable06   --WL01
   FROM RECEIPT (nolock)  
   JOIN RECEIPTDETAIL (nolock) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey 
   JOIN STORER (nolock) ON RECEIPTDETAIL.StorerKey = STORER.StorerKey 
   JOIN SKU (nolock) ON  SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku 
   JOIN PACK (nolock) ON SKU.PackKey = PACK.PackKey    
   LEFT OUTER JOIN PO (NOLOCK) ON (PO.Pokey = RECEIPTDETAIL.POKEY)
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowToLoc'      
                                             AND CL.LONG = 'r_receipt_tallysheet86' AND CL.STORERKEY = RECEIPTDETAIL.STORERKEY )
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptKeyStart ) AND  
		   ( REceipt.receiptkey <= @c_ReceiptKeyEnd ) AND
			( RECEIPT.Storerkey >= @c_StorerKeyStart ) AND
			( RECEIPT.Storerkey <= @c_StorerKeyEnd ) 
   GROUP BY STORER.Company,   
            RECEIPT.ReceiptKey,   
            RECEIPT.CarrierReference,   
            RECEIPT.StorerKey,   
            RECEIPT.CarrierName,  
            PO.SellerName,   
            RECEIPT.ReceiptDate,   
            RECEIPTDETAIL.Sku,   
            RECEIPTDETAIL.Lottable02,   
            SKU.DESCR,   
            RECEIPTDETAIL.Lottable04,   
            RECEIPTDETAIL.UOM,   
            RECEIPT.CarrierAddress1,
            RECEIPT.POkey,
            PACK.CaseCnt,
            RECEIPTDETAIL.Lottable03,
            RECEIPT.Signatory,
            RECEIPT.Userdefine01,
            RECEIPT.Facility,
            RECEIPTDETAIL.lottable01,
            RECEIPT.Containerkey,
            RECEIPT.containertype,
            RECEIPTDETAIL.ReceiptLinenumber,
            SKU.RetailSku,
            SKU.AltSku,
            SKU.ManufacturerSku,
            RECEIPT.ExternReceiptKey,
            SKU.SUSR3,
            SKU.SUSR4,
            SKU.Shelflife,
            SKU.IVAS,
            RECEIPTDETAIL.Lottable09,
            RECEIPT.notes, 
            SKU.Lottable02label,
            --START (ML01)
            RECEIPTDETAIL.Lottable12,
            RECEIPTDETAIL.Lottable08,
            RECEIPTDETAIL.Lottable10,
            RECEIPTDETAIL.Lottable11,
            RECEIPTDETAIL.ExternPOKey,
            RECEIPTDETAIL.Userdefine02,
            CASE WHEN RECEIPTDETAIL.StorerKey = 'IDSMED' THEN SKU.SKUGroup ELSE '' END,
            --END (ML01)
            RECEIPTDETAIL.toloc,     
            ISNULL(CL.SHORT,''),
            ISNULL(RECEIPTDETAIL.Lottable06,'')   --WL01
   
     ORDER BY RECEIPT.ReceiptKey, RECEIPTDETAIL.ReceiptLineNumber 

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ReceiptTallySheet86'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
    
   WHILE @@TRANCOUNT < @n_StartTCnt   
      BEGIN TRAN;     
  
END

GO