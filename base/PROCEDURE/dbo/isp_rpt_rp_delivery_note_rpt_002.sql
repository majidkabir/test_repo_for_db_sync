SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/      
/* Stored Procedure: isp_RPT_RP_DELIVERY_NOTE_RPT_002                      */      
/* Creation Date: 16-FEB-2022                                              */      
/* Copyright: LFL                                                          */      
/* Written by: Harshitha                                                   */      
/*                                                                         */      
/* Purpose: WMS-18911                                                      */      
/*                                                                         */      
/* Called By: rpt_rp_delivery_note_rpt_002                                 */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 17-Feb-2022  CSCHONG 1.0   DEvops Scripts Combine                       */  
/***************************************************************************/  
CREATE   PROCEDURE [dbo].[isp_RPT_RP_DELIVERY_NOTE_RPT_002]  
                                        @c_stoterkey               NVARCHAR(10),  
                                        @c_loadkey                 NVARCHAR(10),  
                                        @dt_OrderDate_start        DATETIME,  
                                        @dt_OrderDate_End          DATETIME,  
                                        @c_Externorderkey_start    NVARCHAR(50),  
                                        @c_Externorderkey_End      NVARCHAR(50)   
   
  
 AS      
BEGIN  
   
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
 SELECT ExternOrderkey = OH.ExternOrderkey  
   ,TWDOYY    = DATEDIFF(yy, CONVERT(DATETIME, '1911-01-01'), OH.DeliveryDate)    
   ,TWDOMM    = MONTH(OH.DeliveryDate)    
   ,TWDODD    = DAY(OH.DeliveryDate)    
   ,DeliveryDate = OH.DeliveryDate     
   ,OrderDate    = OH.OrderDate                                                                                                                                                                                                                                
                      
   ,Consigneekey = ISNULL(SUBSTRING(RTRIM(OH.Consigneekey),4,15),'')                                                                                                                                                                                           
                                                                                                                              
   ,C_Company    = ISNULL(RTRIM(OH.C_Company),'')                                                                                                                                                                                                              
                                                                                                                              
   ,C_Address1   = ISNULL(RTRIM(OH.C_Address1),'')                                                                                                                                                                                                             
                                                                                                                              
   ,C_Address2   = ISNULL(RTRIM(OH.C_Address2),'')    
   ,C_Address3   = ISNULL(RTRIM(OH.C_Address3),'')     
   ,C_City     = ISNULL(RTRIM(OH.C_City),'')    
   ,BuyerPO    = ISNULL(RTRIM(OH.BuyerPO),'')   
   ,Notes        = ISNULL(OH.Notes,'')                                                                                                                                                                                                                         
                     
   ,Sku          = ISNULL(RTRIM(OD.Sku),'')                                                                                                                                                                                                                    
                                                                                                                              
   ,SkuDescr     = ISNULL(RTRIM(SKU.Descr),'')   
   ,Qty          = (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)  
   ,PackUOM1     = ISNULL(RTRIM(CS.Long),'')  
   ,CaseCnt    = ISNULL(PACK.CaseCnt,0)  
   ,PackUOM3     = ISNULL(RTRIM(EA.Long),'')  
         ,C_Contact1   = ISNULL(RTRIM(OH.C_Contact1),'')    
         ,C_Phone1   = ISNULL(RTRIM(OH.C_Phone1),'')    
 FROM ORDERS         OH   WITH (NOLOCK)                                                                                                                                                                                                                        
                                                                                                       
 JOIN ORDERDETAIL    OD   WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)                                                                                                                                                                                         
                                                                                                                                       
 JOIN SKU            SKU  WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey) AND (OD.Sku= SKU.Sku)                                                                                                                                                                 
                                                                                                                                       
 JOIN PACK           PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)     
 JOIN CODELKUP       EA   WITH (NOLOCK) ON (EA.ListName = 'MHUOM' and EA.Short = PACK.PACKUOM3)   
 JOIN CODELKUP       CS   WITH (NOLOCK) ON (CS.ListName = 'MHUOM' and CS.Short = PACK.PACKUOM1)                                                                                                                                                                
                                                                                                                                                        
 WHERE OH.Storerkey= @c_stoterkey  
 AND   ISNULL(RTRIM(OH.LoadKey),'') = CASE WHEN ISNULL(RTRIM(@c_loadkey),'') = '' THEN ISNULL(RTRIM(OH.LoadKey),'') ELSE RTRIM(@c_loadkey) END   
 AND   OH.ExternOrderkey BETWEEN @c_Externorderkey_start AND @c_Externorderkey_End  
 AND   OH.DeliveryDate BETWEEN @dt_OrderDate_start AND @dt_OrderDate_end  
 AND   OH.Status   >= '3'   
 AND   OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty > 0      
   ORDER BY OD.ExternOrderkey, OD.ExternLineNo                                                                                                                                                                                                                 
                                                                                                                                    
 END        

SET QUOTED_IDENTIFIER OFF 

GO