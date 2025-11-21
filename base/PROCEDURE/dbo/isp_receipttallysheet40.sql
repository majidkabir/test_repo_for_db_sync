SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/***************************************************************************/  
/* Store Procedure: isp_ReceiptTallySheet40                                */  
/* Creation Date: 01-JUL-2014                                              */  
/* Copyright: LF                                                           */  
/* Written by: YTWan                                                       */  
/*                                                                         */  
/* Purpose: SOS#314642 - [TW] 20784 - Create a New Tally Sheet             */  
/*          (Report Type TALLYSHT)                                         */  
/* Called By: PB: r_receipt_tallysheet40                                   */  
/*                                                                         */  
/* PVCS Version: 1.1                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author    Ver.  Purposes                                   */  
/* 2014-10-29   CSCHONG   1.0   SOS324167 (CS01)                           */  
/* 2018-02-12   SPChin    1.1   INC0128600 - Add Filter By Storerkey       */  
/* 2018-04-30   CSCHONG   1.2   WMS-4766 - revised field logic (CS02)      */  
/***************************************************************************/  
CREATE PROC [dbo].[isp_ReceiptTallySheet40]  
           @c_ReceiptStart    NVARCHAR(10)   
         , @c_ReceiptEnd      NVARCHAR(10)  
         , @c_PrincipalStart  NVARCHAR(15)  
         , @c_PrincipalEnd    NVARCHAR(15)  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_Storerkey    NVARCHAR(15)  
         , @n_NoOfLine     INT  
  
   SET @n_NoOfLine = 10   
  
   SELECT STORER.Company    
     ,   RECEIPT.Facility  
     ,   RECEIPT.Storerkey  
     ,   RECEIPT.ReceiptKey    
     ,   RECEIPT.ReceiptDate   
     ,   RECEIPT.ExternReceiptKey   
     ,   RECEIPT.POKey   
     ,   RECEIPT.CarrierReference  
     ,   RECEIPT.WarehouseReference  
   ,   RECEIPT.ContainerKey  
   ,   ContainerType = (SELECT TOP 1 CODELKUP.Description   
                          FROM CODELKUP (NOLOCK)  
            WHERE CODELKUP.Listname = 'CONTAINERT'  
          AND CODELKUP.Code = RECEIPT.CarrierName   
                          AND (CODELKUP.StorerKey = Receipt.StorerKey   
                               OR ISNULL(CODELKUP.StorerKey,'')= '')  
                          ORDER BY CODELKUP.StorerKey DESC) --INC0128600  
     ,   RECEIPTDETAIL.Sku     
     ,   SKU.DESCR     
     ,   RECEIPTDETAIL.UOM     
     ,   RECEIPTDETAIL.PackKey     
     ,   QtyExpected = CASE WHEN RECEIPTDETAIL.UOM = PACK.PACKUOM1 AND PACK.CaseCnt > 0   
                            THEN RECEIPTDETAIL.QtyExpected / PACK.CaseCnt   
           WHEN RECEIPTDETAIL.UOM = PACK.PACKUOM4 AND PACK.CaseCnt > 0    
                      THEN RECEIPTDETAIL.QtyExpected/Pack.Pallet  
        ELSE RECEIPTDETAIL.QtyExpected END  
     ,   RECEIPTDETAIL.BeforeReceivedQty    
     --,   QtyReceived = CASE WHEN RECEIPTDETAIL.UOM = PACK.PACKUOM1 AND PACK.CaseCnt > 0   
     --                       THEN RECEIPTDETAIL.QtyReceived / PACK.CaseCnt ELSE RECEIPTDETAIL.QtyReceived END  
     ,  QtyReceived = CASE WHEN PACK.Pallet <> 0 THEN RECEIPTDETAIL.QtyExpected / PACK.pallet ELSE 0 END  
     ,   SKU.ShelfLife      
     ,   SKU.Length  
     ,   SKU.Width  
     ,   SKU.Height  
     ,   PACK.Casecnt  
     ,   PACK.PalletHI   
     ,   PACK.PalletTI  
     ,   RecGroup   =(Row_Number() OVER (PARTITION BY RECEIPT.ReceiptKey ORDER BY RECEIPT.ReceiptKey, RECEIPTDETAIL.SKU Asc)-1)/@n_NoOfLine  
   ,   RECEIPT.CarrierKey                            --(CS01)  
     ,   RECEIPT.CarrierName          --(CS01)  
   FROM RECEIPT        WITH (NOLOCK)   
   JOIN RECEIPTDETAIL  WITH (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey   
   JOIN SKU            WITH (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey and SKU.Sku = RECEIPTDETAIL.Sku   
   JOIN STORER         WITH (NOLOCK) ON RECEIPT.Storerkey = STORER.Storerkey   
   JOIN PACK           WITH (NOLOCK) ON PACK.packkey = SKU.packkey   
   --LEFT OUTER JOIN CODELKUP WITH(NOLOCK) ON CODELKUP.LISTNAME = 'CONTAINERT' AND CODELKUP.CODE = RECEIPT.CarrierName --INC0128600   
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptStart )      
   AND   ( RECEIPT.ReceiptKey <= @c_ReceiptEnd )      
   AND   ( RECEIPT.Storerkey  >= @c_PrincipalStart )     
   AND   ( RECEIPT.Storerkey  <= @c_PrincipalEnd )   
   AND   ( RECEIPTDETAIL.QtyExpected > 0 )  
  
END  
  
SET QUOTED_IDENTIFIER OFF   

GO