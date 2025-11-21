SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Procedure: isp_RPT_MB_DRIVER_001                              */        
/* Creation Date: 29-SEP-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-20741 (SG)                                              */      
/*                                                                      */        
/* Called By: RPT_MB_DRIVER_001         								*/        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 29-SEP-2022  WZPang   1.0  DevOps Combine Script                     */     
/************************************************************************/        
CREATE PROC [dbo].[isp_RPT_MB_DRIVER_001] (
      @c_Mbolkey NVARCHAR(10)    
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        

   SELECT   STORER.Company,  
            STORER.Address1,  
            STORER.Address2,  
            STORER.Address3,  
            STORER.Address4,  
            STORER.City,  
            STORER.State,  
            STORER.Zip,  
            STORER.Country,  
            ORDERS.C_Company,  
            ORDERS.C_Address1,  
            ORDERS.C_Address2,  
            ORDERS.C_Address3,  
            ORDERS.C_Address4,  
            ORDERS.C_City,  
            ORDERS.C_State,  
            ORDERS.C_Zip,  
            ORDERS.C_Country,  
            ORDERS.DeliveryDate,  
            ORDERS.ExternOrderkey,  
            ORDERS.UserDefine04,  
            MBOL.MbolKey,  
            SKU.SKUGroup,  
            SUM(PACKDETAIL.Qty) AS QTY,
            COUNT (DISTINCT PACKDETAIL.LabelNo) AS LabelNo,
	        C_Addr = CASE WHEN TRIM(ISNULL(C_Address1,'')) = '' THEN '' ELSE TRIM(ISNULL(C_Address1,'')) + CHAR(10) + CHAR(13) END +
                 CASE WHEN TRIM(ISNULL(C_Address2,'')) = '' THEN '' ELSE TRIM(ISNULL(C_Address2,'')) + CHAR(10) + CHAR(13) END +
                 CASE WHEN TRIM(ISNULL(C_Address3,'')) = '' THEN '' ELSE TRIM(ISNULL(C_Address3,'')) + CHAR(10) + CHAR(13) END +
                 CASE WHEN TRIM(ISNULL(C_Address4,'')) = '' THEN '' ELSE TRIM(ISNULL(C_Address4,'')) + CHAR(10) + CHAR(13) END +
				 CASE WHEN TRIM(ISNULL(C_City,'')) ='' THEN '' ELSE TRIM(ISNULL(C_City,'')) + CHAR(9) END +
				 CASE WHEN TRIM(ISNULL(C_State,'')) ='' THEN '' ELSE TRIM(ISNULL(C_State,'')) + CHAR(10) + CHAR(13) END +
				 CASE WHEN TRIM(ISNULL(C_Zip,'')) ='' THEN '' ELSE TRIM(ISNULL(C_Zip,''))   END 
   FROM MBOL (NOLOCK)  
   JOIN MBOLDETAIL  WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)          
   JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)    
   JOIN STORER WITH (NOLOCK) ON (STORER.Storerkey = ORDERS.Storerkey)  
   --JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = Orders.Orderkey AND ORDERDETAIL.Storerkey = Orders.Storerkey)  
   JOIN PACKHEADER WITH (NOLOCK) ON (PackHeader.OrderKey = ORDERS.OrderKey)
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PackHeader.PickSlipNo)
   JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PACKDETAIL.StorerKey AND SKU.SKU = PACKDETAIL.SKU)  
   WHERE MBOL.MbolKey = @c_Mbolkey  
   GROUP BY STORER.Company,  
            STORER.Address1,  
            STORER.Address2,  
            STORER.Address3,  
            STORER.Address4,  
            STORER.City,  
            STORER.State,  
            STORER.Zip,  
            STORER.Country,  
            ORDERS.C_Company,  
            ORDERS.C_Address1,  
            ORDERS.C_Address2,  
            ORDERS.C_Address3,  
            ORDERS.C_Address4,  
            ORDERS.C_City,  
            ORDERS.C_State,  
            ORDERS.C_Zip,  
            ORDERS.C_Country,  
            ORDERS.DeliveryDate,  
            ORDERS.ExternOrderkey,  
            ORDERS.UserDefine04,  
            MBOL.MbolKey,  
            SKU.SKUGroup,
            PACKDETAIL.StorerKey

END -- procedure    

GO