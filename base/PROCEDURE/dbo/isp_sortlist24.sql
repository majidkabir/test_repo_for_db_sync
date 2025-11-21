SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Stored Proc: isp_sortlist24                                          */  
/* Creation Date: 06-APR-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-12630  - [PH] - Adidas Loading Guide                    */  
/*        :                                                             */  
/* Called By: r_dw_sortlist24                                           */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 26-JUN-2020 CSCHONG  1.1   WMS-12630 add new field (CS01)            */
/************************************************************************/  
CREATE PROC [dbo].[isp_sortlist24]  
           @c_Loadkey         NVARCHAR(10)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT   
  
         , @c_Storerkey       NVARCHAR(15) = ''  
         , @c_RptByODUOM      NVARCHAR(10) = 'N'  
  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   WHILE @@TRANCOUNT > 0   
   BEGIN  
      COMMIT TRAN  
   END  
  
   IF OBJECT_ID('tempdb..#TMP_SORTLIST24','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_SORTLIST24;  
   END  
  
   CREATE TABLE #TMP_SORTLIST24 
        (   RowID             INT   IDENTITY(1,1)  PRIMARY KEY  
        ,   Loadkey           NVARCHAR(10)      
        ,   Facility          NVARCHAR(10)      
        ,   LPRoute           NVARCHAR(20)      
        ,   CarrierKey        NVARCHAR(30)      
        ,   TruckSize         NVARCHAR(20)      
        ,   Driver            NVARCHAR(45)    
        ,   Consigneekey      NVARCHAR(30)    
        ,   C_Company         NVARCHAR(45)      
        ,   C_Address1        NVARCHAR(45)      
        ,   C_Address2        NVARCHAR(45)     
        ,   C_Address3        NVARCHAR(45)     
        ,   C_Address4        NVARCHAR(45)     
        ,   C_City            NVARCHAR(45)     
        ,   Externorderkey    NVARCHAR(50)    
        ,   STCompany         NVARCHAR(45)    
        ,   PickHeaderKey     NVARCHAR(10)     
        ,   Storerkey         NVARCHAR(15)     
        ,   Sku               NVARCHAR(20)     
        ,   ID                NVARCHAR(18)       
        ,   Lottable01        NVARCHAR(18)      
        ,   Lottable10        NVARCHAR(30)    
        ,   Prepared          NVARCHAR(10)    
        ,   ReportType        NVARCHAR(1)     
        ,   LEXTLoadKey       NVARCHAR(20)    
        ,   LPriority         NVARCHAR(10)    
        ,   LPuserdefDate01   DATETIME
        ,   CopyName          NVARCHAR(18)     
        ,   Copycode          NVARCHAR(30)     
        ,   Copyshowcolumn    NVARCHAR(18)   
        ,   QtyPick           INT                      --(CS01)                  
        )  
  
    
      INSERT INTO #TMP_SORTLIST24 
      (     Loadkey           
      ,   Facility            
      ,   LPRoute           
      ,   CarrierKey         
      ,   TruckSize           
      ,   Driver            
      ,   Consigneekey      
      ,   C_Company             
      ,   C_Address1            
      ,   C_Address2           
      ,   C_Address3           
      ,   C_Address4           
      ,   C_City               
      ,   Externorderkey       
      ,   STCompany          
      ,   PickHeaderKey      
      ,   Storerkey         
      ,   Sku                
      ,   ID                   
      ,   Lottable01         
      ,   Lottable10 
      ,   Prepared  
      ,   ReportType
      ,   LEXTLoadKey   
      ,   LPriority
      ,   LPuserdefDate01      
      ,   CopyName           
      ,   Copycode          
      ,   Copyshowcolumn      
      ,   QtyPick                               --(CS01)
      )  
      SELECT  LOADPLAN.Loadkey
         ,  LOADPLAN.Facility
         ,  ISNULL(LOADPLAN.Route,'')
         ,  ISNULL(LOADPLAN.CarrierKey,'')
         ,  ISNULL(LOADPLAN.TruckSize,'')
         ,  ISNULL(LOADPLAN.Driver,'')
         ,  ORDERS.Consigneekey
         ,  ISNULL(ORDERS.C_Company,'')
         ,  ISNULL(ORDERS.C_Address1,'')
         ,  ISNULL(ORDERS.C_Address2,'')
         ,  ISNULL(ORDERS.C_Address3,'')
         ,  ISNULL(ORDERS.C_Address4,'')
         ,  ISNULL(ORDERS.C_City,'')
         ,  ORDERS.Externorderkey
         ,  STORER.Company
         ,   PICKHEADER.PickHeaderKey
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.Sku 
         ,  PICKDETAIL.ID
         ,  LOTATTRIBUTE.Lottable01
         ,  LOTATTRIBUTE.Lottable10
         ,  Prepared = CONVERT(char(10), SUSER_NAME())  
         ,  ReportType = ''
         ,  LEXTLoadKey      = Loadplan.Externloadkey 
         ,  LPriority        = Loadplan.Priority 
         ,  LPuserdefDate01  = ISNULL(Loadplan.LPuserdefDate01,'')
         ,  CL2.Description AS Copyname
         ,  CL2.Code AS Copycode
         ,  CL2.Short AS Copyshowcolumn
         , QtyPicked = SUM(PICKDETAIL.qty)                                   --(CS01)
   FROM LOADPLAN WITH (NOLOCK)
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
   JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.orderkey = ORDERS.OrderKey) 
   JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)  
   JOIN PICKDETAIL   WITH (NOLOCK) ON  (ORDERS.Orderkey = PICKDETAIL.Orderkey)
   JOIN REFKEYLOOKUP WITH (NOLOCK) ON (PICKDETAIL.PickDetailKey = REFKEYLOOKUP.PickDetailKey)  
   JOIN PICKHEADER WITH (NOLOCK) ON (REFKEYLOOKUP.PickSlipNo = PICKHEADER.PickHeaderkey)
                                 AND(LOADPLAN.LoadKey= PICKHEADER.ExternOrderkey) 
   JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey) 
                           AND(PICKDETAIL.Sku = SKU.Sku) 
   JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
   JOIN LOTATTRIBUTE WITH (NOLOCK) on (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) 
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCOPY' AND CL2.Long = 'r_dw_sortlist24' AND CL2.Storerkey = ORDERS.StorerKey ) 
   WHERE loadplan.loadkey = @c_Loadkey 
   GROUP BY LOADPLAN.Loadkey
         ,  LOADPLAN.Facility
         ,  ISNULL(LOADPLAN.Route,'')
         ,  ISNULL(LOADPLAN.CarrierKey,'')
         ,  ISNULL(LOADPLAN.TruckSize,'')
         ,  ISNULL(LOADPLAN.Driver,'')
         ,  ORDERS.Consigneekey
         ,  ISNULL(ORDERS.C_Company,'')
         ,  ISNULL(ORDERS.C_Address1,'')
         ,  ISNULL(ORDERS.C_Address2,'')
         ,  ISNULL(ORDERS.C_Address3,'')
         ,  ISNULL(ORDERS.C_Address4,'')
         ,  ISNULL(ORDERS.C_City,'')
         ,  ORDERS.Externorderkey
         ,  STORER.Company
         ,  PICKHEADER.PickHeaderKey
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.Sku 
         ,  PICKDETAIL.ID
         ,  LOTATTRIBUTE.Lottable01
         ,  LOTATTRIBUTE.Lottable10
         ,  Loadplan.Externloadkey 
         ,  Loadplan.Priority 
         ,  ISNULL(Loadplan.LPuserdefDate01,'')
         ,  CL2.Description
         ,  CL2.Code 
         ,  CL2.Short                  
   ORDER BY PICKHEADER.PickHeaderKey
         ,  ORDERS.ExternOrderkey
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.Sku 
 
  
QUIT_SP:     
   SELECT   Loadkey           
      ,   Facility            
      ,   LPRoute           
      ,   CarrierKey         
      ,   TruckSize           
      ,   Driver            
      ,   Consigneekey      
      ,   C_Company             
      ,   C_Address1            
      ,   C_Address2           
      ,   C_Address3           
      ,   C_Address4           
      ,   C_City               
      ,   Externorderkey       
      ,   STCompany          
      ,   PickHeaderKey      
      ,   Storerkey         
      ,   substring(Sku,1,6)                
      ,   ID                   
      ,   Lottable01         
      ,   Lottable10 
      ,   Prepared  
      ,   ReportType
      ,   LEXTLoadKey   
      ,   LPriority
      ,   LPuserdefDate01      
      ,   CopyName           
      ,   Copycode          
      ,   Copyshowcolumn  
      ,   sum(QtyPick) as QtyPick                     --(CS01)
   FROM #TMP_SORTLIST24 SL24     
   WHERE loadkey = @c_Loadkey    
   GROUP BY Loadkey           
      ,   Facility            
      ,   LPRoute           
      ,   CarrierKey         
      ,   TruckSize           
      ,   Driver            
      ,   Consigneekey      
      ,   C_Company             
      ,   C_Address1            
      ,   C_Address2           
      ,   C_Address3           
      ,   C_Address4           
      ,   C_City               
      ,   Externorderkey       
      ,   STCompany          
      ,   PickHeaderKey      
      ,   Storerkey         
      ,   substring(Sku,1,6)                
      ,   ID                   
      ,   Lottable01         
      ,   Lottable10 
      ,   Prepared  
      ,   ReportType
      ,   LEXTLoadKey   
      ,   LPriority
      ,   LPuserdefDate01      
      ,   CopyName           
      ,   Copycode          
      ,   Copyshowcolumn     
     -- ,   QtyPick                          --(CS01)            
   ORDER BY PickHeaderKey  
         ,  ISNULL(Externorderkey,'')  
         ,  Storerkey  
         ,  substring(Sku,1,6)  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
END  

GO