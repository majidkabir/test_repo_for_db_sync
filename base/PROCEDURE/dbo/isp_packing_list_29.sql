SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/                    
/* Store Procedure: isp_Packing_List_29                                       */                    
/* Creation Date: 01-SEP-2016                                                 */                    
/* Copyright: IDS                                                             */                    
/* Written by: CSCHONG                                                        */                    
/*                                                                            */                    
/* Purpose: SOS#374874 - CN Dickies Packing list                              */        
/*                                                                            */                    
/*                                                                            */                    
/* Called By:  r_dw_packing_list_29                                           */                    
/*                                                                            */                    
/* PVCS Version: 1.0                                                          */                    
/*                                                                            */                    
/* Version: 1.0                                                               */                    
/*                                                                            */                    
/* Data Modifications:                                                        */                    
/*                                                                            */                    
/* Updates:                                                                   */                    
/* Date         Author    Ver.  Purposes                                      */       
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length           */         
/* 17-Apr-2020  WinSern   1.2   removed pickdetail.caseid check (ws01)        */    
/* 09-Apr-2021  CSCHONG   1.3   WMS-16024 PB-Standardize TrackingNo (CS01)    */ 
/******************************************************************************/           
        
CREATE PROC [dbo].[isp_Packing_List_29]                   
       (@c_Orderkey NVARCHAR(10),      
        @c_labelno  NVARCHAR(20))                    
AS                  
BEGIN                              
   SET ANSI_WARNINGS OFF                  
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF       
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @c_MCompany        NVARCHAR(45)        
         , @c_Externorderkey  NVARCHAR(50)    --tlting_ext      
         , @c_C_Addresses     NVARCHAR(200)         
         , @c_loadkey         NVARCHAR(10)        
         , @c_Userdef03       NVARCHAR(20)        
         , @c_salesman        NVARCHAR(30)        
         , @c_phone1          NVARCHAR(18)      
         , @c_contact1        NVARCHAR(30)        
        
         , @n_TTLQty          INT         
         , @c_shippername     NVARCHAR(45)        
         , @c_Sku             NVARCHAR(20)        
         , @c_Size            NVARCHAR(5)        
         , @c_PickLoc         NVARCHAR(10)       
         , @n_NoOfLine        INT        
         , @c_getOrdKey       NVARCHAR(10)      
      
 SET @n_NoOfLine = 6      
 SET @c_getOrdKey = ''                --(CS01)      
        
        
 CREATE TABLE #PACKLIST29      
         ( c_Contact1      NVARCHAR(30) NULL       
         , C_Addresses     NVARCHAR(200) NULL      
         , c_Phone1        NVARCHAR(18) NULL      
         , c_Phone2        NVARCHAR(18) NULL      
         , M_Company       NVARCHAR(45) NULL       
         , Externorderkey  NVARCHAR(50) NULL   --tlting_ext      
         , PickLOC         NVARCHAR(10)  NULL      
         , SKUSize         NVARCHAR(10) NULL         
         , ORDUdef04       NVARCHAR(20) NULL       
         , PSKU            NVARCHAR(20)  NULL      
         , Pqty            INT                     
   , OrderKey        NVARCHAR(10)  NULL                
         , Loadkey         NVARCHAR(10)  NULL              
         , Altsku       NVARCHAR(20)  NULL              
         , Shipperkey      NVARCHAR(15)  NULL        
         , SDescr          NVARCHAR(150)  NULL       
         , RecGrp          INT      
         )        
               
               
   /*CS01 Start*/      
         
IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)      
              WHERE Orderkey = @c_Orderkey)      
   BEGIN      
    SET @c_getOrdKey = @c_Orderkey       
   END                 
   ELSE      
   BEGIN      
    SELECT DISTINCT @c_getOrdKey = OrderKey      
    FROM PackHeader AS ph WITH (NOLOCK)      
    WHERE ph.PickSlipNo=@c_Orderkey      
   END        
         
   /*CS01 END*/            
        
   INSERT INTO #PACKLIST29 (      
                          c_Contact1              
                        , C_Addresses            
                        , c_Phone1        
                        , c_phone2           
                        , M_Company       
                        , Externorderkey            
                        , PickLOC                               
                        , SKUSize                            
                        , ORDUdef04                
                        , PSKU                  
                        , Pqty                        
                        , OrderKey                   
                        , Loadkey                   
                        , Altsku                        
                        , Shipperkey                   
                        , SDescr       
                        , RecGrp)                   
   SELECT ISNULL(OH.c_Contact1,''),(OH.C_address2 + OH.C_address3 + OH.C_address4),      
                   ISNULL(OH.C_Phone1,''),ISNULL(OH.C_Phone2,''),ISNULL(OH.M_Company,''),      
                   OH.Externorderkey,PD.LOC,s.size,      
                   --ISNULL(OH.Userdefine04,''),         --CS01
                   ISNULL(OH.TrackingNo,''),              --CS01 
                   PD.SKU,PD.qty,OH.OrderKey,      
                   OH.Loadkey,S.Altsku,OH.shipperkey,S.descr,      
                   (Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.LOC Asc)-1)/@n_NoOfLine       
   FROM ORDERS OH WITH (NOLOCK)      
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey      
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey       
                            AND PD.orderlinenumber = ORDDET.orderlinenumber      
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey      
   JOIN STORER STO WITH (NOLOCK) ON OH.shipperkey = STO.Storerkey                                 
   WHERE PD.Orderkey = @c_getOrdKey--@c_orderkey                                --(CS01)      
   --AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END                --ws01    
   ORDER By PD.LOC      
        
        
                   SELECT c_Contact1              
                        , C_Addresses            
                        , c_Phone1        
                        , c_phone2           
                        , M_Company       
                        , Externorderkey            
                        , PickLOC                               
                        , SKUSize                            
                        , ORDUdef04                
                        , PSKU                  
                        , Pqty                        
                        , OrderKey                   
                        , Loadkey                   
                        , Altsku                        
                        , Shipperkey                   
                        , SDescr      
                        , RecGrp      
   FROM #PACKLIST29        
   ORDER BY PickLoc        
                     
END      



GO