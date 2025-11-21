SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/      
/* Stored Procedure: isp_RPT_RP_DELIVERY_ORDER_TW01                        */      
/* Creation Date: 07-FEB-2022                                              */      
/* Copyright: LFL                                                          */      
/* Written by: Harshitha                                                   */      
/*                                                                         */      
/* Purpose: WMS-18888                                                      */      
/*                                                                         */      
/* Called By: rpt_rp_delivery_order_tw01                                   */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 08-Feb-2022  CHONGCS 1.0   DevOps Combine Script                        */    
/***************************************************************************/  
  
CREATE   PROC [dbo].[isp_RPT_RP_DELIVERY_ORDER_TW01]      
                                                            @c_stoterkey             NVARCHAR(10),  
                                                            @c_orderkey_Start        NVARCHAR(10),   
                                                            @c_Orderkey_End          NVARCHAR(10),   
                                                            @dt_OrderDate_start      DATETIME,  
                                                            @dt_OrderDate_End        DATETIME,  
                                                            @dt_DeliveryDate_start   DATETIME,  
                                                            @dt_DeliveryDate_End     DATETIME  
AS      
BEGIN  
   
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
SELECT ST.Company,OH.StorerKey,OH.ConsigneeKey,OH.C_Company,OH.ORDERKEY,  
(ISNULL(RTRIM(OH.C_CITY),'')+ISNULL(RTRIM(OH.C_ADDRESS1),'')+ISNULL(RTRIM(OH.C_ADDRESS2),'')) AS C_ADD,  
(ISNULL(RTRIM(OH.Notes),'') + ISNULL(RTRIM (OH.Notes2),'')) AS ORDNOTES,OH.ExternOrderKey,OH.BuyerPO,  
OH.DeliveryDate,OH.OrderDate,OD.Sku,S.DESCR,P.CaseCnt,  
  
SUM(PD.Qty) AS ORDQTY,                 
'' as Lottable02     
FROM ORDERS OH WITH (NOLOCK)  
JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey  
JOIN STORER AS ST WITH (NOLOCK) ON ST.StorerKey = OH.StorerKey AND ST.[type]='1'  
JOIN SKU AS S WITH (NOLOCK) ON S.Sku = OD.Sku AND S.StorerKey=OD.StorerKey   
JOIN PACk AS P WITH (NOLOCK) ON P.PackKeY =S.PACKKey  
                               
JOIN PICKDETAIL PD (NOLOCK) on PD.StorerKey = OD.StorerKey and PD.orderkey = OD.orderkey and PD.orderlinenumber = OD.orderlinenumber and PD.SKU = OD.SKU   
                 
WHERE OH.Storerkey = CASE WHEN ISNULL(@c_stoterkey,'') = '' THEN OH.Storerkey ELSE @c_stoterkey END   
AND OH.Orderkey >= CASE WHEN ISNULL(@c_orderkey_Start,'') = '' THEN OH.Orderkey ELSE @c_orderkey_Start END  
AND OH.Orderkey <= CASE WHEN ISNULL(@c_Orderkey_End,'') = '' THEN OH.Orderkey ELSE @c_Orderkey_End END  
AND OH.Orderdate  >= CASE WHEN ISNULL( @dt_OrderDate_start,'') <> '' THEN   @dt_OrderDate_start ELSE OH.Orderdate END  
AND OH.Orderdate  <= CASE WHEN ISNULL(@dt_OrderDate_End,'') <> '' THEN @dt_OrderDate_End ELSE OH.Orderdate END  
AND OH.deliverydate  >= CASE WHEN ISNULL(@dt_DeliveryDate_start,'') <> '' THEN  @dt_DeliveryDate_start ELSE OH.deliverydate END  
AND OH.deliverydate  <= CASE WHEN ISNULL(@dt_DeliveryDate_End,'') <> '' THEN @dt_DeliveryDate_End ELSE OH.deliverydate END  
AND OH.status>='2'  
  
GROUP BY ST.Company,OH.StorerKey,OH.ConsigneeKey,OH.C_Company,OH.ORDERKEY,  
(ISNULL(RTRIM(OH.C_CITY),'')+ISNULL(RTRIM(OH.C_ADDRESS1),'')+ISNULL(RTRIM(OH.C_ADDRESS2),'')) ,  
(ISNULL(RTRIM(OH.Notes),'') +ISNULL(RTRIM (OH.Notes2),'')),OH.ExternOrderKey,OH.BuyerPO,  
OH.DeliveryDate,OH.OrderDate,OD.Sku,S.DESCR,P.CaseCnt  
  
ORDER BY OH.Orderkey, MIN(OD.OrderLineNumber)  
  
END        
SET QUOTED_IDENTIFIER OFF 

GO