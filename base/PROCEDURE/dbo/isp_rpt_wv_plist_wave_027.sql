SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/      
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_027                             */      
/* Creation Date: 22-JUN-2023                                              */      
/* Copyright: LFL                                                          */      
/* Written by: CSCHONG                                                     */      
/*                                                                         */      
/* Purpose: WMS-22817 PRT_DeliveryNotes_CR                                 */      
/*                                                                         */      
/* Called By: rpt_RPT_WV_PLIST_WAVE_027                                    */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 22-JUN-2022  CSCHONG 1.0   DEvops Scripts Combine                       */  
/***************************************************************************/  
CREATE   PROCEDURE [dbo].[isp_RPT_WV_PLIST_WAVE_027]  
                                        @c_Wavekey               NVARCHAR(10) 
   
  
 AS      
BEGIN  
   
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
         SELECT 
                  STORER.Company,
                  OH.Storerkey, 
                  OH.Orderkey,
                  OH.Externorderkey,
                  OH.Consigneekey, 
                  OH.C_Company,
                  OH.Buyerpo,
                  OH.EditDate,
                  OH.Deliverydate,
                  OH.Notes,
                  OH.C_ADDRESS1,
                  OH.C_Phone1,
                  OH.Loadkey,
                  --OD.OrderLineNumber,
                  --OD.ExternLineNo,
                  OD.Lottable01,
                  SKU.Descr,
                  OD.SKU,
                  PACK.CASECNT,
                  CASE WHEN OH.Status = '9' THEN SUM(OD.ShippedQty) 
                   ELSE SUM(OD.QtyAllocated + OD.QtyPicked) END AS ShipQ,
                 ROW_NUMBER() OVER ( PARTITION BY OH.Orderkey ORDER BY  OH.Orderkey ) AS RecNo,
                 SKU.ManufacturerSku
         FROM ORDERS (NOLOCK) AS OH LEFT JOIN ORDERDETAIL (NOLOCK) AS OD ON OH.ORDERKEY=OD.ORDERKEY
         LEFT JOIN SKU (NOLOCK) ON OD.STORERKEY=SKU.STORERKEY AND OD.SKU=SKU.SKU
         LEFT JOIN PACK (NOLOCK) ON SKU.PACKKEY=PACK.PACKKEY
         JOIN STORER (NOLOCK) ON STORER.StorerKey = OH.StorerKey AND STORER.type='1'
         WHERE OH.STATUS >='2'
         AND OH.UserDefine09 = @c_Wavekey
         Group by
                  STORER.Company,
                  OH.Storerkey, 
                  OH.Orderkey,
                  OH.Externorderkey,
                  OH.Consigneekey, 
                  OH.C_Company,
                  OH.Buyerpo,
                  OH.EditDate,
                  OH.Deliverydate,
                  OH.Notes,
                  OH.C_ADDRESS1,
                  OH.C_Phone1,
                  OH.Loadkey,
                  --OD.OrderLineNumber,
                  --OD.ExternLineNo,
                  OD.Lottable01,
                  SKU.Descr,
                  OD.SKU,
                  PACK.CASECNT,
                  OH.Status,SKU.ManufacturerSku
         order by OH.storerkey,OH.orderkey
                                                                                                                                                                                                              
                                                                                                                                    
 END        

SET QUOTED_IDENTIFIER OFF 

GO