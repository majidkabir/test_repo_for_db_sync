SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptTallySheet61                                 */  
/* Creation Date: 19-Dec-2018                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-7315 IDP Receiving RCMReport                            */ 
/*            copy from isp_ReceiptTallySheet_TWN_01                    */   
/*        :                                                             */  
/* Called By: r_receipt_tallysheet61                                    */
/*            copy from r_dw_receipttallysheet_twn_01                   */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/ 

CREATE PROC [dbo].[isp_ReceiptTallySheet61]  
            @c_ReceiptKeyStart   NVARCHAR(10)  
         ,  @c_ReceiptKeyEnd     NVARCHAR(10)  
         ,  @c_StorerKeyStart    NVARCHAR(15)  
         ,  @c_StorerKeyEnd      NVARCHAR(15)  
  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
  SELECT RH.Storerkey
      ,dbo.fn_Encode_IDA_Code128(RTRIM(RH.ExternReceiptKey)) AS ExternReceiptKeyCode  
      ,CONVERT(VARCHAR,RH.EffectiveDate,111) AS N'到貨日'  
      ,RH.ContainerKey AS N'櫃號'  
      ,RH.BilledContainerQty AS N'進貨板數'  
      ,RTRIM(RH.ExternReceiptKey) AS ExternReceiptKey  
      ,RH.ReceiptKey  
      ,RTRIM(RH.WarehouseReference) AS N'棧板編號'  
      ,RTRIM(SKU.itemclass) + '/' + RTRIM(SKU.SKUGROUP) AS N'Brand/商品分類'  
      ,RTRIM(RD.Sku) AS N'貨號/箱號' 
      ,dbo.fn_Encode_IDA_Code128(RTRIM(RD.Sku)) AS SKU  
      ,'DESCR' = CASE WHEN RTRIM(SKU.ITEMCLASS)='19' AND RTRIM(SKU.NOTES1)<>'' THEN RTRIM(SKU.NOTES1) ELSE RTRIM(SKU.DESCR) END  
      ,SUM(RD.QtyExpected) AS QtyExpected  
      ,dbo.fn_Encode_IDA_Code128(RTRIM(RH.ReceiptKey)) AS ReceiptKeyCode 
      ,ISNULL(RH.ContainerQty,0) AS ContainerQTY
      ,SUM(RD.QtyReceived) AS QtyReceived
      ,CONVERT(NVARCHAR,RD.Lottable04,111) AS Lottable04
   FROM RECEIPTDETAIL RD WITH (NOLOCK)  
      JOIN RECEIPT RH WITH (NOLOCK) ON RH.ReceiptKey=RD.ReceiptKey  
      JOIN SKU WITH (NOLOCK) ON SKU.StorerKey=RD.StorerKey AND SKU.Sku=RD.Sku  
      JOIN PACK WITH (NOLOCK) ON PACK.PackKey=SKU.PACKKey  
   WHERE --RH.StorerKey='LOR'  
     -- AND 
   RH.DOCTYPE='A'  
   --   AND RH.EffectiveDate >= @c_Receipt_Adddate_Start  
   --   AND RH.EffectiveDate <= @c_Receipt_Adddate_End  
   --AND RH.UserDefine03 >= @Invoice_No_Start  
   --AND RH.UserDefine03 <= @Invoice_No_End  
   AND RH.ReceiptKey BETWEEN @c_ReceiptKeyStart AND @c_ReceiptKeyEnd  
   AND RH.Storerkey BETWEEN @c_StorerkeyStart AND @c_StorerkeyEnd  
   AND RD.QtyExpected > 0  
   GROUP BY RH.UserDefine03,RH.ContainerType,RH.StorerKey,RH.EffectiveDate  
                  ,RH.ContainerKey,RH.BilledContainerQty,RD.PutawayLoc,SKU.Style,RH.ExternReceiptKey  
      ,RH.ReceiptKey,RH.WarehouseReference,SKU.itemclass,SKU.SKUGROUP,RD.Sku,RD.UserDefine03  
      ,SKU.DESCR,SKU.Altsku,SKU.Manufacturersku,SKU.NOTES1, ISNULL(RH.ContainerQty,0),RD.Lottable04  
   ORDER BY RH.ReceiptKey,RD.Sku     
  
END

GO