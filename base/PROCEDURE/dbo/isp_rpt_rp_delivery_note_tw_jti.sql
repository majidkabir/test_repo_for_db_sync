SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/      
/* Stored Procedure: isp_RPT_RP_DELIVERY_NOTE_TW_JTI                       */      
/* Creation Date: 23-FEB-2022                                              */      
/* Copyright: LFL                                                          */      
/* Written by: Harshitha                                                   */      
/*                                                                         */      
/* Purpose: WMS-18987                                                      */      
/*                                                                         */      
/* Called By: RPT_RP_DELIVERY_NOTE_TW_JTI                                  */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 24-FEB-2022  CSCHONG 1.0   DEvops Scripts Combine                       */   
/***************************************************************************/  
CREATE    PROCEDURE [dbo].[isp_RPT_RP_DELIVERY_NOTE_TW_JTI]  
                                                                   @c_storerkey               NVARCHAR(10),  
                                                                   @c_wavekey_start           NVARCHAR(10),  
                                                                   @c_wavekey_End             NVARCHAR(10),  
                                                                   @dt_deliverydate_start     DATETIME,  
                                                                   @dt_deliverydate_End       DATETIME  
   
   
 AS      
BEGIN  
   
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
SELECT ST.Company ,OH.StorerKey as storerkey,OH.ConsigneeKey as consigneekey,OH.C_Company as c_company,OH.ORDERKEY as orderkey,  
CASE OH.type   
WHEN 'JTI-N' THEN N'出貨單'  
  WHEN 'JTI-EX' THEN N'換貨單'   
  WHEN 'JTI-RPN' THEN N'補貨單'  
  WHEN 'JTI-CON' THEN N'內領單'   
  WHEN 'JTI-SAMPLE' THEN N'樣品領用單'  
  WHEN 'JTI-POSM' THEN 'JTIPOSM'  
  ELSE 'Others' END as OHType,  
(ISNULL(RTRIM(OH.C_ADDRESS1),'')) AS C_ADD,  
ISNULL(RTRIM(OH.Notes),'')  AS ORDNOTES,OH.ExternOrderKey,ISNULL(OH.BuyerPO,'') AS buyerpo,ISNULL(OH.C_Phone1,'') AS c_phone1,  
OH.DeliveryDate as deliverydate,OH.EditDate as EditDate,OH.[Route] as ORDRoute,PDET.Sku as Sku,  
(RTRIM(ISNULL(S.DESCR,''))+ Rtrim (ISNULL(S.Busr1,''))+ Rtrim(ISNULL(S.Busr2,'')) + '(' +CASE LOTT.Lottable03  
  WHEN 'JPN' THEN N'日本'  
  WHEN 'MYS' THEN N'馬來西亞'   
  WHEN 'RUS' THEN N'俄羅斯'  
  WHEN 'TUR' THEN N'土耳其'   
  WHEN 'TWN' THEN N'台灣'  
  WHEN 'RO' THEN N'羅馬尼亞'   
  WHEN 'UA' THEN N'烏克蘭'  
  WHEN 'PL' THEN N'波蘭'   
   WHEN 'DE' THEN N'德國'   
  ELSE '其他' END + ')' +  
CASE WHEN OD.Userdefine01='F' THEN N'贈煙' ELSE '' END) as Descr,P.CaseCnt as CaseCnt,P.InnerPack as InnerPack,P.PackUOM3 as UOM,  
SUM(PDET.Qty) AS ShipQTY,LOTT.Lottable04 as Lot04,LOTT.Lottable06 as Lot06  
FROM WAVEDETAIL WDET WITH (NOLOCK)  
JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WDET.OrderKey  
JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey  
JOIN PICKDETAIL PDET WITH (NOLOCK) ON PDET.OrderKey=OD.OrderKey AND PDET.Sku=OD.Sku AND PDET.OrderLineNumber = OD.OrderLineNumber  
JOIN STORER AS ST WITH (NOLOCK) ON ST.StorerKey = OH.StorerKey AND ST.[type]='1'  
JOIN LOTATTRIBUTE AS LOTT WITH (NOLOCK) ON LOTT.Lot = PDET.Lot AND LOTT.StorerKey = PDET.Storerkey AND LOTT.Sku = PDET.Sku  
JOIN SKU AS S WITH (NOLOCK) ON S.Sku = OD.Sku AND S.StorerKey=OD.StorerKey   
JOIN PACk AS P WITH (NOLOCK) ON P.PackKeY =S.PACKKey  
WHERE OH.Storerkey = CASE WHEN ISNULL(@c_storerkey,'') = '' THEN OH.Storerkey ELSE @c_storerkey END   
AND WDET.Wavekey >= CASE WHEN ISNULL(@c_wavekey_start,'') = '' THEN WDET.Wavekey ELSE @c_wavekey_start END  
AND WDET.Wavekey <= CASE WHEN ISNULL(@c_wavekey_End,'') = '' THEN WDET.Wavekey  ELSE @c_wavekey_End END  
AND OH.deliverydate  >= CASE WHEN ISNULL(@dt_deliverydate_start,'') <> '' THEN  @dt_deliverydate_start ELSE OH.deliverydate END  
AND OH.deliverydate  <= CASE WHEN ISNULL(@dt_deliverydate_End,'') <> '' THEN @dt_deliverydate_End ELSE OH.deliverydate END  
AND OH.status>='5'  
GROUP BY ST.Company ,OH.StorerKey,OH.ConsigneeKey ,OH.C_Company ,OH.ORDERKEY ,  
CASE OH.type   
WHEN 'JTI-N' THEN N'出貨單'  
  WHEN 'JTI-EX' THEN N'換貨單'   
  WHEN 'JTI-RPN' THEN N'補貨單'  
  WHEN 'JTI-CON' THEN N'內領單'   
  WHEN 'JTI-SAMPLE' THEN N'樣品領用單'  
  WHEN 'JTI-POSM' THEN 'JTIPOSM'  
  ELSE 'Others' END ,  
(ISNULL(RTRIM(OH.C_ADDRESS1),'')) ,  
ISNULL(RTRIM(OH.Notes),'')  ,OH.ExternOrderKey,ISNULL(OH.BuyerPO,'') ,ISNULL(OH.C_Phone1,'') ,  
OH.DeliveryDate,OH.EditDate,OH.[Route],PDET.Sku ,  
(RTRIM(ISNULL(S.DESCR,''))+ Rtrim (ISNULL(S.Busr1,''))+ Rtrim(ISNULL(S.Busr2,'')) + '(' +CASE LOTT.Lottable03  
  WHEN 'JPN' THEN N'日本'  
  WHEN 'MYS' THEN N'馬來西亞'   
  WHEN 'RUS' THEN N'俄羅斯'  
  WHEN 'TUR' THEN N'土耳其'   
  WHEN 'TWN' THEN N'台灣'  
  WHEN 'RO' THEN N'羅馬尼亞'   
  WHEN 'UA' THEN N'烏克蘭'  
  WHEN 'PL' THEN N'波蘭'   
   WHEN 'DE' THEN N'德國'   
  ELSE '其他' END + ')' +  
CASE WHEN OD.Userdefine01='F' THEN N'贈煙' ELSE '' END) ,P.CaseCnt ,P.InnerPack ,P.PackUOM3,  
LOTT.Lottable04 ,LOTT.Lottable06   
ORDER BY OH.Orderkey,MIN(OD.OrderLineNumber), PDET.Sku  

END        

SET QUOTED_IDENTIFIER OFF 

GO