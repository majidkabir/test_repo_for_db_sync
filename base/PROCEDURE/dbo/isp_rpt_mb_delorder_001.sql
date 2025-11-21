SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/      
/* Stored Procedure: isp_RPT_MB_DELORDER_001                               */      
/* Creation Date: 23-FEB-2022                                              */      
/* Copyright: LFL                                                          */      
/* Written by: Harshitha                                                   */      
/*                                                                         */      
/* Purpose: WMS-18989                                                      */      
/*                                                                         */      
/* Called By: RPT_MB_DELORDER_001                                          */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/***************************************************************************/  
CREATE   PROCEDURE [dbo].[isp_RPT_MB_DELORDER_001]  
                                   @c_mbolkey           NVARCHAR(10)  
   
   
 AS      
BEGIN  
   
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
  
SELECT MBOL.MBOLKey,     
 ORDERS.StorerKey,   
   Company = CASE WHEN CSG.CustomerGroupCode = 'YFY' THEN CSG.CustomerGroupName ELSE STORER.Company END,   
 ISNULL(STORER.Address1 ,'') Address1,  
 ISNULL(STORER.Address2 ,'') Address2,  
 ISNULL(STORER.Address3 ,'') Address3,  
 ISNULL(STORER.Address4 ,'') Address4,      
 ORDERS.OrderKey,    
 ORDERS.ExternOrderKey,   
   ORDERS.Consigneekey,  
 ORDERS.C_Company,  
 ORDERS.C_Phone1,  
 ISNULL(ORDERS.C_Address1 ,'') C_Address1,  
 ISNULL(ORDERS.C_Address2 ,'') C_Address2,  
 ISNULL(ORDERS.C_Address3 ,'') C_Address3,  
 ISNULL(ORDERS.C_Address4 ,'') C_Address4,      
 ORDERS.AddDate,  
   ORDERS.Facility,   
 ORDERS.DeliveryDate,  
   CONVERT(NVARCHAR(250),ORDERS.Notes) AS Notes,  
 ORDERDETAIL.Sku,   
   ORDERDETAIL.Uom,   
 SKU.Descr,   
   FLOOR((ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) /     
                     CASE ORDERDETAIL.UOM  
                        WHEN PACK.PACKUOM1 THEN PACK.CaseCnt  
                        WHEN PACK.PACKUOM2 THEN PACK.InnerPack  
                        WHEN PACK.PACKUOM3 THEN 1  
                        WHEN PACK.PACKUOM4 THEN PACK.Pallet  
                        WHEN PACK.PACKUOM5 THEN PACK.Cube  
                        WHEN PACK.PACKUOM6 THEN PACK.GrossWgt  
                        WHEN PACK.PACKUOM7 THEN PACK.NetWgt  
                        WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1  
                        WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2  
                     END) AS ShippedQty,  
   /*ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty),*/  
   ORDERDETAIL.Orderlinenumber,  
 SKU.RetailSku,  
   ISNULL(DELADDR.Address1,'') AS daddress1,   
   ISNULL(DELADDR.Address2,'') AS daddress2,   
   ISNULL(DELADDR.Address3,'') AS daddress3,   
   ISNULL(DELADDR.Address4,'') AS daddress4,  
   CASE WHEN ISNULL(CLR.short,'N') = 'Y' THEN ORDERS.ExternPOKey ELSE '' END AS ExternPOKey  
FROM MBOL (NOLOCK)  
INNER JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)  
INNER JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)  
INNER JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)  
INNER JOIN STORER (NOLOCK) ON (STORER.StorerKey = ORDERS.StorerKey)  
INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND  
         SKU.SKU = ORDERDETAIL.SKU)  
INNER JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)   
LEFT JOIN STORER CSG WITH (NOLOCK) ON (CSG.STORERKEY = ORDERS.Consigneekey)  
LEFT JOIN STORER DELADDR WITH (NOLOCK) ON DELADDR.Storerkey = ORDERS.Consigneekey   
LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'showextpokey'                                          
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_delivery_order_02' AND ISNULL(CLR.Short,'') <> 'N')   
WHERE MBOL.MBOLKey = @c_mbolkey   
AND ORDERS.Status >= '5'  
 END        

SET QUOTED_IDENTIFIER OFF 

GO