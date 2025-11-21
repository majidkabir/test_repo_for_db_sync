SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/        
/* Stored Procedure: isp_RPT_RP_DELIVERY_NOTE_RPT_001                      */        
/* Creation Date: 07-FEB-2022                                              */        
/* Copyright: LFL                                                          */        
/* Written by: Harshitha                                                   */        
/*                                                                         */        
/* Purpose: WMS-18889                                                      */        
/*                                                                         */        
/* Called By: rpt_rp_delivery_note_rpt_001                                 */        
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
    
CREATE      PROC [dbo].[isp_RPT_RP_DELIVERY_NOTE_RPT_001]        
      @c_stoterkey             NVARCHAR(10),    
      @c_orderkey_Start        NVARCHAR(10),     
      @c_Orderkey_End          NVARCHAR(10),     
      @dt_OrderDate_start      DATETIME,    
      @dt_OrderDate_End        DATETIME,    
      @dt_DeliveryDate_start   DATETIME,    
      @dt_DeliveryDate_End     DATETIME,    
      @c_Wavekey               NVARCHAR(10)    
AS        
BEGIN    
     
   SET NOCOUNT ON         
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF         
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
SELECT Storer.CustomerGroupName    
  ,Orders.C_Company    
  ,Orders.Consigneekey    
  ,Orders.C_Phone1    
  ,Orders.C_Address1    
  ,Orders.Notes    
  ,Pickheader.Pickheaderkey    
  ,Orders.Orderkey    
  ,Orders.Externorderkey    
  ,Orders.Userdefine02    
  ,Orders.Deliverydate    
  ,Orderdetail.Sku    
  ,SKU.Descr    
  ,CASE WHEN orders.status = '9' THEN SUM(Orderdetail.ShippedQty)     
          ELSE SUM(Orderdetail.QtyAllocated + Orderdetail.QtyPicked) END AS SumShippedQty    
  ,Orders.Userdefine09    
  ,ROW_NUMBER() OVER (PARTITION BY Orders.Orderkey ORDER BY Pickheader.Pickheaderkey ,Orders.Orderkey,Orders.Externorderkey,Orderdetail.Sku) AS rowno   
  FROM Orders WITH (NOLOCK)    
  JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY)    
  JOIN STORER WITH (NOLOCK) ON (STORER.StorerKey = ORDERS.StorerKey)    
  JOIN SKU WITH (NOLOCK) ON (SKU.STORERKEY = Orderdetail.STORERKEY) AND (SKU.SKU = Orderdetail.SKU)    
  JOIN PICKHEADER WITH (NOLOCK) ON (PICKHEADER.ORDERKEY = ORDERS.ORDERKEY)    
  WHERE Orders.StorerKey = @c_stoterkey AND Orders.OrderKey BETWEEN @c_orderkey_Start AND @c_Orderkey_End    
  AND ORDERS.ORDERDATE BETWEEN @dt_OrderDate_start AND @dt_OrderDate_End    
  AND ORDERS.DeliveryDate BETWEEN @dt_DeliveryDate_start AND @dt_DeliveryDate_End    
         AND Orders.Userdefine09 = CASE WHEN ISNULL(@c_wavekey,'') <> '' THEN @c_Wavekey ELSE Orders.Userdefine09 END    
  GROUP BY    
  Storer.CustomerGroupName    
  ,Orders.C_Company    
  ,Orders.Consigneekey    
  ,Orders.C_Phone1    
  ,Orders.C_Address1    
  ,Orders.Notes    
  ,Pickheader.Pickheaderkey    
  ,Orders.Orderkey    
  ,Orders.Externorderkey    
  ,Orders.Userdefine02    
  ,Orders.Deliverydate    
  ,Orderdetail.Sku    
  ,SKU.Descr     
  ,orders.status    
  ,Orders.Userdefine09       
    
   END          
  

GO