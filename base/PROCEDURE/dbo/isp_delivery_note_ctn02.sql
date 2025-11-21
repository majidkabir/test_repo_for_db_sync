SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: isp_delivery_note_ctn02                                     */  
/* Creation Date: 28-APR-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:WMS-12861 SG - Prestige - Delivery Note                      */  
/*        :                                                             */  
/* Called By: r_dw_delivery_note_ctn02                                  */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 22-JAN-21    CSCHONG   1.1 WMS-16120 add recgrp (CS01)               */
/************************************************************************/  
CREATE PROC [dbo].[isp_delivery_note_ctn02]  
            @c_orderkey     NVARCHAR(10)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF     
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
   
         , @c_Consigneekey    NVARCHAR(15)  
         , @c_TransMehtod     NVARCHAR(30)  
         , @d_ShipDate4ETA    DATETIME  
         , @d_ETA             DATETIME  
         , @c_Rptsku          NVARCHAR(5)  
         , @n_NoOfLine        INT              --CS01
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  

   SET @n_NoOfLine = 15                       --CS01
 
  
   CREATE TABLE #DELNOTECTN02  
      (  C_Company         NVARCHAR(45) 
      ,  C_Address1        NVARCHAR(45)  
      ,  C_Address2        NVARCHAR(45)  
      ,  C_Address3        NVARCHAR(45)  
      ,  C_Address4        NVARCHAR(45) 
      ,  OHNotes           NVARCHAR(4000) 
      ,  ST_Company        NVARCHAR(45) 
      ,  DeliveryDate      DATETIME    NULL 
      ,  ExternOrderkey    NVARCHAR(50)   
      ,  Orderkey          NVARCHAR(10)  
      ,  C_State           NVARCHAR(45) 
      ,  SKUDescr          NVARCHAR(60)  
      ,  Qty               INT          
      ,  Sku               NVARCHAR(20)   
      ,  SKUGRP            NVARCHAR(20)     
      ,  SBUSR6            NVARCHAR(30)   
      ,  ItemClass         NVARCHAR(20)    
      ,  C_Zip             NVARCHAR(18) 
      ,  BuyerPO           NVARCHAR(20)   
      ,  MFGDate           DATETIME    NULL  
      ,  C_Country         NVARCHAR(30) 
      ,  Storerkey         NVARCHAR(15)  
      ,  Lottable01        NVARCHAR(18)  
      ,  ExpDate           DATETIME    NULL 
      ,  RecGrp            INT                  --CS01
      )  
  
  INSERT INTO #DELNOTECTN02  
   (     C_Address1         
      ,  C_Address2       
      ,  C_Address3       
      ,  C_Address4        
      ,  OHNotes           
      ,  ST_Company        
      ,  DeliveryDate     
      ,  ExternOrderkey   
      ,  Orderkey         
      ,  C_Company        
      ,  C_State           
      ,  SKUDescr         
      ,  Qty                        
      ,  Sku               
      ,  SKUGRP               
      ,  SBUSR6             
      ,  ItemClass       
      ,  C_Zip            
      ,  BuyerPO             
      ,  MFGDate           
      ,  C_Country        
      ,  Storerkey         
      ,  Lottable01        
      ,  ExpDate  
      ,  RecGrp                           --CS01             
      )  
     SELECT    
         ORDERS.C_Address1,   
         ISNULL(ORDERS.C_Address2,''),   
         ISNULL(ORDERS.C_Address3,''),   
         ISNULL(ORDERS.C_Address4,''),   
         ISNULL(ORDERS.Notes,''),   
         STORER.Company,   
         ORDERS.DeliveryDate,   
         ORDERS.ExternOrderKey,   
         ORDERS.OrderKey,   
         ORDERS.C_Company,
         ISNULL(ORDERS.C_State,''), 
         SKU.DESCR,    
         SUM(PD.qty),    
         ORDERDETAIL.SKU,
         SKU.SKUGROUP,
         ISNULL(SKU.BUSR6,''),  
         SKU.itemclass,  
         ISNULL(ORDERS.C_Zip,''),
         ISNULL(ORDERS.BuyerPO,''),
         CASE WHEN sku.strategykey = 'PPDFEFO' THEN LOTT.lottable14 
                 WHEN sku.strategykey = 'PPDSTD'  THEN LOTT.lottable05 ELSE '' END,
       ORDERS.C_Country,ORDERS.Storerkey,LOTT.lottable01,
       CASE WHEN sku.strategykey = 'PPDFEFO' THEN LOTT.lottable04 
              WHEN sku.strategykey = 'PPDSTD'  THEN  LOTT.lottable04 ELSE '' END,
      (Row_Number() OVER (PARTITION BY ORDERS.Orderkey ORDER BY ORDERS.Orderkey,ORDERDETAIL.SKU Asc)-1)/@n_NoOfLine                     --CS01
    FROM ORDERS WITH (nolock) 
    JOIN STORER WITH (nolock)      ON ( ORDERS.StorerKey = STORER.StorerKey )
    JOIN ORDERDETAIL WITH (nolock) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )  
    JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = ORDERDETAIL.Orderkey AND PD.Sku = ORDERDETAIL.SKU
                                   AND PD.Storerkey = ORDERDETAIL.storerkey AND PD.OrderLineNumber = ORDERDETAIL.OrderLineNumber
    JOIN SKU         WITH (nolock) ON ( ORDERDETAIL.StorerKey = SKU.StorerKey ) and
                                      ( ORDERDETAIL.Sku = SKU.Sku )    
   JOIN lotattribute LOTT  WITH (nolock) ON ( LOTT.Lot = PD.lot ) 
   JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = ORDERS.Storerkey)         
   WHERE  ( ORDERS.Orderkey = @c_orderkey)
  GROUP BY ORDERS.C_Address1,   
         ISNULL(ORDERS.C_Address2,''),   
         ISNULL(ORDERS.C_Address3,''),   
         ISNULL(ORDERS.C_Address4,''),   
         ISNULL(ORDERS.Notes,''),   
         STORER.Company,   
         ORDERS.DeliveryDate,   
         ORDERS.ExternOrderKey,   
         ORDERS.OrderKey,   
         ORDERS.C_Company,
         ISNULL(ORDERS.C_State,''), 
         SKU.DESCR,    
    --     PD.qty,    
         ORDERDETAIL.SKU,
         SKU.SKUGROUP,
         ISNULL(SKU.BUSR6,''),  
         SKU.itemclass,  
         ISNULL(ORDERS.C_Zip,''),
         ISNULL(ORDERS.BuyerPO,''),
         CASE WHEN sku.strategykey = 'PPDFEFO' THEN LOTT.lottable14 
                 WHEN sku.strategykey = 'PPDSTD'  THEN LOTT.lottable05 ELSE '' END,
       ORDERS.C_Country,ORDERS.Storerkey,LOTT.lottable01,
       CASE WHEN sku.strategykey = 'PPDFEFO' THEN LOTT.lottable04 
              WHEN sku.strategykey = 'PPDSTD'  THEN  LOTT.lottable04 ELSE '' END
   --ORDER BY ORDERDETAIL.OrderLineNumber ASC   
 
 
  
   SELECT  *  
   FROM #DELNOTECTN02     
   ORDER BY Recgrp
         ,  Orderkey  
         ,  Storerkey       
         ,  Sku  
  
QUIT:  
 
   drop table #DELNOTECTN02

   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
END -- procedure


GO