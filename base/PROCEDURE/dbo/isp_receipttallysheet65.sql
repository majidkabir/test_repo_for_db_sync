SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/******************************************************************************/                
/* Store Procedure: isp_ReceiptTallySheet65                                   */                
/* Creation Date: 29-Nov-2019                                                 */                
/* Copyright: LFL                                                             */                
/* Written by: WLChooi                                                        */                
/*                                                                            */                
/* Purpose: WMS-11181 - [CN] Porsche_TallySheet                               */    
/*                                                                            */                
/*                                                                            */                
/* Called By:  r_receipt_tallysheet65                                         */                
/*                                                                            */                
/* PVCS Version: 1.0                                                          */                
/*                                                                            */                
/* Version: 1.0                                                               */                
/*                                                                            */                
/* Data Modifications:                                                        */                
/*                                                                            */                
/* Updates:                                                                   */                
/* Date         Author    Ver.  Purposes                                      */      
/******************************************************************************/       
    
CREATE PROC [dbo].[isp_ReceiptTallySheet65]               
       (@c_ReceiptKeyStart NVARCHAR(10),
        @c_ReceiptKeyEnd   NVARCHAR(10),
        @c_StorerKeyStart  NVARCHAR(15),
        @c_StorerKeyEnd    NVARCHAR(15),
        @c_UserID          NVARCHAR(20) = '' )                
AS              
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_WARNINGS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @n_continue        INT = 1

   SELECT RECEIPT.StorerKey, 
          RECEIPT.ReceiptKey,
          RECEIPT.Facility,
          RECEIPTDETAIL.ExternReceiptKey,
          ISNULL(PO.POType,'') AS POType,
          ISNULL(PO.SellersReference,'') AS SellersReference,
          ISNULL(PO.OtherReference,'') AS OtherReference,
          ISNULL(PO.SellerName,'') as SellerName,
          PO.PODate,
          RECEIPTDETAIL.Lottable02,
          RECEIPTDETAIL.SKU,
          --SKU.DESCR,
          ISNULL(SKU.NOTES1,'') AS Notes1,
          RECEIPTDETAIL.Lottable08,
          P.Pallet,
          P.CaseCnt,
          P.InnerPack,
          RECEIPTDETAIL.QtyExpected,
          CONVERT(CHAR(20), @c_UserID) as UserId,
          RECEIPT.RECType,
          ISNULL(RECEIPT.userdefine02,'') AS RDUdf02,
          ISNULL(RECEIPT.userdefine06,'') AS RDUdf06,
          ISNULL(RECEIPT.CarrierReference,'') AS CarrierReff,
          ISNULL(RECEIPT.carrierkey,'') AS CarrierKey,
          ISNULL(RECEIPT.carriername,'') AS CarrierName,
          RECEIPTDETAIL.beforereceivedqty,
          RECEIPTDETAIL.ExternLineNo,
          sku.ivas,
          TotalExtRec = (SELECT count(distinct ExternReceiptkey) from RECEIPTDETAIL where receiptkey = RECEIPT.receiptkey),
          SKU.Altsku,
          ISNULL(SKUINFO.ExtendedField05,'') AS ExtendedField05,
          ISNULL(SKU.IB_UOM,'') AS IB_UOM,
          ISNULL(SKU.IB_RPT_UOM,'') AS IB_RPT_UOM
   FROM RECEIPT (NOLOCK)  
   JOIN RECEIPTDETAIL (NOLOCK) ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)   
   JOIN SKU (NOLOCK) ON (RECEIPTDETAIL.SKU = SKU.SKU AND RECEIPTDETAIL.StorerKey = SKU.StorerKey)
   LEFT JOIN SKUINFO (NOLOCK) ON (RECEIPT.StorerKey = SKUINFO.StorerKey AND SKU.SKU = SKUINFO.SKU)
   LEFT JOIN PO (NOLOCK) ON (RECEIPTDETAIL.POKey = PO.POKey)
   LEFT JOIN PACK P (NOLOCK) ON P.packkey = SKU.PACKKey
   WHERE (RECEIPT.StorerKey >= @c_StorerKeyStart 
      AND RECEIPT.Storerkey <= @c_StorerKeyEnd   
      AND RECEIPT.ReceiptKey >= @c_ReceiptKeyStart   
      AND RECEIPT.Receiptkey <= @c_ReceiptKeyEnd  )  
   ORDER BY RECEIPT.ReceiptKey,RECEIPTDETAIL.SKU,RECEIPTDETAIL.Lottable02,RECEIPTDETAIL.ExternLineNo
   
                 
END  

GO