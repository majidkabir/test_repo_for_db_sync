SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/******************************************************************************/                
/* Store Procedure: isp_ReceiptTallySheet74                                   */                
/* Creation Date: 30-DEC-2020                                                 */                
/* Copyright: LFL                                                             */                
/* Written by: CSCHONG                                                        */                
/*                                                                            */                
/* Purpose: WMS-15954 RG - Lego - Inbound Tally Sheet                         */    
/*                                                                            */                
/*                                                                            */                
/* Called By:  r_receipt_tallysheet74                                         */                
/*                                                                            */                
/* PVCS Version: 1.0                                                          */                
/*                                                                            */                
/* Version: 1.0                                                               */                
/*                                                                            */                
/* Data Modifications:                                                        */                
/*                                                                            */                
/* Updates:                                                                   */                
/* Date         Author    Ver.  Purposes                                      */ 
/* 04-Apr-2021  mingle01    1.1   add RECEIPT.EffectiveDate                   */     
/******************************************************************************/       
    
CREATE PROC [dbo].[isp_ReceiptTallySheet74]               
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

     SELECT STORER.Company,        
         RECEIPT.ReceiptKey,   
         RECEIPT.CarrierReference,   
         RECEIPT.StorerKey,   
         RECEIPT.CarrierName,
         PO.SellerName,   
         RECEIPT.ReceiptDate,   
         RECEIPTDETAIL.Sku,   
         UPPER(RECEIPTDETAIL.Lottable02) as receiptdetail_lottable02,   
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
         (SELECT CODELKUP.Description FROM CODELKUP (nolock) WHERE CODELKUP.listname='CONTAINERT' AND CODELKUP.code = RECEIPT.ContainerType) AS containertype,
         RECEIPTDETAIL.ReceiptLinenumber,
         SKU.RetailSku,
         SKU.AltSku,
         SKU.ManufacturerSku,
         CONVERT(NVARCHAR(50),@c_UserID) AS userid,
         CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowBarcode,      
         RECEIPT.ExternReceiptKey,
         SKU.SUSR3,
         SKU.SUSR4,
         (SELECT ISNULL(CODELKUP.short,0) FROM CODELKUP (nolock) 
          WHERE CODELKUP.Storerkey=RECEIPT.Storerkey AND CODELKUP.listname='REPORTCFG' 
         AND CODELKUP.code = 'SHOWFIELD'  and Long = 'r_receipt_tallysheet74') AS SHOWFIELD,
         SKU.Shelflife,
         convert(nvarchar(10),DATEADD(DAY,SKU.Shelflife,RECEIPT.ReceiptDate),101) As ExpDate,
         ISNULL(SKU.IVAS,'') AS IVAS,
         RECEIPTDETAIL.Lottable08,
         CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowLot09 
        ,RECEIPTDETAIL.Lottable06
        ,PACK.Pallet
        ,RECEIPT.Sellername
        ,RECEIPT.Notes,
         ISNULL(SKU.BUSR7,'') AS UDF12,
         ISNULL(SKU.MEASUREMENT,'') AS MEASUREMENT, 
         PACK.WIDTHUOM1,
         PACK.LENGTHUOM1,
         PACK.HEIGHTUOM1,
         PACK.NETWGT,
         PACK.WIDTHUOM2,
         PACK.LENGTHUOM2,
         PACK.HEIGHTUOM2,
         PACK.GROSSWGT,
         PACK.WIDTHUOM3,
         PACK.LENGTHUOM3,
         PACK.HEIGHTUOM3,
         ISNULL(CASE RECEIPTDETAIL.UOM 
         WHEN 'EA' THEN PACK.GrossWgt
         WHEN 'CARTON' THEN PACK.NetWgt
         END,'') AS WEIGHT,
         CASE WHEN ISNULL(CLR2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowLogitechField,
         RECEIPTDETAIL.Lottable07 as LOTT7,
         PACK.OtherUnit1 as POTHUNIT1,
         CASE WHEN ISNULL(SKU.busr9,'') = '' THEN 'NEW' ELSE '' END AS SKUFLAG,
         CASE WHEN ISNULL(CLR3.code2,'N') = 'Y' AND ISNULL(CLR4.code2,'') = '' AND ISNULL(CLR5.code2,'') <> '' THEN CLR5.long else '' END  AS MCLBL,
         RECEIPT.EffectiveDate         --ML01
    FROM RECEIPT (nolock)  
         JOIN RECEIPTDETAIL (nolock) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey 
         JOIN STORER (nolock) ON RECEIPTDETAIL.StorerKey = STORER.StorerKey 
         JOIN SKU (nolock) ON  SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku 
         JOIN PACK (nolock) ON SKU.PackKey = PACK.PackKey
         LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (RECEIPT.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWBARCODE' 
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_receipt_tallysheet74' AND ISNULL(CLR.Short,'') <> 'N') 
         LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (RECEIPT.Storerkey = CLR1.Storerkey AND CLR1.Code = 'showlot09' 
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_receipt_tallysheet74' AND ISNULL(CLR1.Short,'') <> 'N') 
         LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (RECEIPT.Storerkey = CLR2.Storerkey AND CLR2.Code = 'showlogitechfield'   
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_receipt_tallysheet74' AND ISNULL(CLR2.Short,'') <> 'N')  
         LEFT OUTER JOIN PO (NOLOCK) ON (PO.Pokey = RECEIPTDETAIL.POKEY)
         JOIN SKUINFO SIF (nolock) ON  SKU.StorerKey = SIF.StorerKey AND SKU.Sku = SIF.Sku 
         LEFT JOIN CODELKUP CLR3 (NOLOCK) ON CLR3.listname = 'CustParam' AND CLR3.storerkey = RECEIPT.Storerkey AND CLR3.code='MCLABELREQ'
         LEFT JOIN CODELKUP CLR4 (NOLOCK) ON CLR4.listname = 'CustParam' AND CLR4.storerkey = RECEIPT.Storerkey AND CLR4.code='MCLABELVENDOR' 
                                            AND CLR4.code2=Receipt.sellercompany
         LEFT JOIN CODELKUP CLR5 (NOLOCK) ON CLR5.listname = 'CustParam' AND CLR5.storerkey = RECEIPT.Storerkey AND CLR5.code='MCLABELHSCODE' 
                                            AND CLR5.code2=substring(SIF.extendedfield01,1, len(CLR5.code2)) 
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
         RECEIPT.ContainerType,
         RECEIPTDETAIL.ReceiptLinenumber,
         SKU.RetailSku,
         SKU.AltSku,
         SKU.ManufacturerSku,
         CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END,
         ISNULL(CLR.Code,''),
         RECEIPT.ExternReceiptKey,
         SKU.SUSR3,
         SKU.SUSR4,
         SKU.Shelflife,
         SKU.IVAS,
         RECEIPTDETAIL.Lottable08,
         CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END 
        ,RECEIPTDETAIL.Lottable06
        ,PACK.Pallet
        ,RECEIPT.Sellername
        ,RECEIPT.Notes ,
         ISNULL(SKU.BUSR7,''),
         ISNULL(SKU.MEASUREMENT,''),
         PACK.WIDTHUOM1,
         PACK.LENGTHUOM1,
         PACK.HEIGHTUOM1,
         PACK.NETWGT,
         PACK.WIDTHUOM2,
         PACK.LENGTHUOM2,
         PACK.HEIGHTUOM2,
         PACK.GROSSWGT,
         PACK.WIDTHUOM3,
         PACK.LENGTHUOM3,
         PACK.HEIGHTUOM3,
         PACK.PackUOM3,
         PACK.PackUOM1,
         ISNULL(CASE RECEIPTDETAIL.UOM 
         WHEN 'EA' THEN PACK.GrossWgt
         WHEN 'CARTON' THEN PACK.NetWgt
         END,''),
         CASE WHEN ISNULL(CLR2.Code,'') <> '' THEN 'Y' ELSE 'N' END,
         RECEIPTDETAIL.Lottable07 , PACK.OtherUnit1,
         CASE WHEN ISNULL(SKU.busr9,'') = '' THEN 'NEW' ELSE '' END, 
         CASE WHEN ISNULL(CLR3.code2,'N') = 'Y' AND ISNULL(CLR4.code2,'') = '' AND ISNULL(CLR5.code2,'') <> '' THEN CLR5.long else '' END,
         RECEIPT.EffectiveDate         --ML01 
    ORDER BY RECEIPT.ReceiptKey, CASE WHEN ISNULL(CLR.Code,'') <> '' THEN RECEIPTDETAIL.Lottable02+RECEIPTDETAIL.Sku ELSE '' END,  RECEIPTDETAIL.ReceiptLinenumber 


   
                 
END  

GO