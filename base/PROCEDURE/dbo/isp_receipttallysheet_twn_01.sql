SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*  
Store Procedure: isp_ReceiptTallySheet_TWN_01  
Creation Date: 11-APR-2018  
Written by: KEVIN  
Purpose: replease Hyperion LOR012_RDT進貨驗收單  
Called by: PB: r_ReceiptTallySheet_TWN_01  
Version: 1.0  
*/  

/*************************************************************************/    
/* Stored Procedure: isp_ReceiptTallySheet_TWN_01                        */    
/* Creation Date: 11-APR-2018                                            */    
/* Copyright: LFL                                                        */    
/* Written by: KEVIN                                                     */    
/*                                                                       */    
/* Purpose: replease Hyperion LOR012_RDT進貨驗收單                        */    
/*                                                                       */    
/* Called By: r_ReceiptTallySheet_TWN_01                                 */    
/*                                                                       */    
/* GitLab Version: 1.0                                                   */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */
/* 2020-07-24   WLChooi  1.1  WMS-14240 - Modify Logic (WL01)            */   
/*************************************************************************/   

CREATE PROC [dbo].[isp_ReceiptTallySheet_TWN_01]  
           @c_Receipt_Adddate_Start    DATETIME  
         , @c_Receipt_Adddate_End      DATETIME  
         , @Invoice_No_Start           NVARCHAR(30)  
         , @Invoice_No_End             NVARCHAR(30)  
  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   SELECT RTRIM(RH.UserDefine03) AS Invoice_No  
         ,N'到貨方式' =  (SELECT TOP 1 CODELKUP.Description   
                         FROM CODELKUP (NOLOCK)  
                         WHERE CODELKUP.Listname = 'CONTAINERT'  
                         AND CODELKUP.Code = RH.ContainerType   
                         AND (CODELKUP.StorerKey = RH.StorerKey   
                         OR ISNULL(CODELKUP.StorerKey,'')= '')  
                         ORDER BY CODELKUP.StorerKey DESC )   
         ,CONVERT(VARCHAR,RH.EffectiveDate,111) AS N'到貨日'  
         ,RH.ContainerKey AS N'櫃號'  
         ,RH.BilledContainerQty AS N'進貨板數'  
         --WL01 START
         --,N'急貨' = CASE WHEN SUBSTRING(RD.PutawayLoc,1,4) = 'A1EP'   
         --                THEN SUBSTRING(RD.PutawayLoc,8,1) ELSE '' END  
         ,N'急貨' = CASE WHEN SUBSTRING(RD.PutawayLoc,1,4) = (SELECT TOP 1 TRIM(Short) FROM CODELKUP CL (NOLOCK) 
                                                             WHERE CL.LISTNAME='LocGroup' AND CL.CODE ='LOR-EP'
                                                             AND (CL.StorerKey = RH.StorerKey OR ISNULL(CL.StorerKey,'') = '')
                                                             ORDER BY CL.StorerKey DESC)
                         THEN SUBSTRING(RD.PutawayLoc,8,1) ELSE '' END
         --WL01 END
         ,RTRIM(SKU.Style) AS N'火'  
         ,RTRIM(RH.ExternReceiptKey) AS ExternReceiptKey  
         ,RH.ReceiptKey  
         ,RTRIM(RH.WarehouseReference) AS N'棧板編號'  
         ,RTRIM(SKU.itemclass) + '/' + RTRIM(SKU.SKUGROUP) AS N'Brand/商品分類'  
         ,RTRIM(RD.Sku) + '/' + RTRIM(RD.UserDefine03) AS N'貨號/箱號'  
         --,MASTER.dbo.fnc_IDAutomation_Uni_C128(RTRIM(RD.Sku),1) AS SKU  
         , dbo.fn_Encode_IDA_Code128(RTRIM(RD.Sku)) AS SKU  
         ,'DESCR' = CASE WHEN RTRIM(SKU.ITEMCLASS)='19' AND RTRIM(SKU.NOTES1)<>'' THEN RTRIM(SKU.NOTES1) ELSE RTRIM(SKU.DESCR) END  
         ,N'IntBarCode' = CASE WHEN ISNULL(SKU.Manufacturersku,'')=''   
                               THEN RTRIM(SKU.Altsku) ELSE RTRIM(SKU.Manufacturersku) END  
         ,SUM(RD.QtyExpected) AS QtyExpected  
         --,MASTER.dbo.fnc_IDAutomation_Uni_C128(RTRIM(RH.ReceiptKey),1) AS ReceiptKeyCode  
         ,dbo.fn_Encode_IDA_Code128(RTRIM(RH.ReceiptKey)) AS ReceiptKeyCode  
   FROM RECEIPTDETAIL RD WITH (NOLOCK)  
   JOIN RECEIPT RH WITH (NOLOCK) ON RH.ReceiptKey=RD.ReceiptKey  
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey=RD.StorerKey AND SKU.Sku=RD.Sku  
   JOIN PACK WITH (NOLOCK) ON PACK.PackKey=SKU.PACKKey  
   WHERE RH.StorerKey='LOR'  
   AND RH.DOCTYPE='A'  
   AND RH.EffectiveDate >= @c_Receipt_Adddate_Start  
   AND RH.EffectiveDate <= @c_Receipt_Adddate_End  
   AND RH.UserDefine03 >= @Invoice_No_Start  
   AND RH.UserDefine03 <= @Invoice_No_End  
   AND RD.QtyExpected > 0  
   GROUP BY RH.UserDefine03,RH.ContainerType,RH.StorerKey,RH.EffectiveDate  
           ,RH.ContainerKey,RH.BilledContainerQty,RD.PutawayLoc,SKU.Style,RH.ExternReceiptKey  
           ,RH.ReceiptKey,RH.WarehouseReference,SKU.itemclass,SKU.SKUGROUP,RD.Sku,RD.UserDefine03  
           ,SKU.DESCR,SKU.Altsku,SKU.Manufacturersku,SKU.NOTES1  
   ORDER BY RH.ReceiptKey,RD.Sku     

END    

GO