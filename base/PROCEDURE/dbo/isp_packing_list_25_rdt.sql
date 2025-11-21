SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_25_rdt                                   */              
/* Creation Date: 16-Aug-2016                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: SOS#374686 - CN CNA Packing list                                  */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_215_rdt                                      */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */ 
/* 2021-Apr-09 CSCHONG  1.1   WMS-16024 PB-Standardize TrackingNo (CS01)      */   
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Packing_List_25_rdt]             
       (@c_Orderkey NVARCHAR(10),
        @c_labelno  NVARCHAR(20))              
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_MCompany        NVARCHAR(45)  
         , @c_Externorderkey  NVARCHAR(30)  
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
  
  
 CREATE TABLE #PACKLIST25 
         ( c_Contact1      NVARCHAR(30) NULL 
         , C_Addresses     NVARCHAR(200) NULL
         , OrdPmtTerm      NVARCHAR(10) NULL
         , OrdAddDate      NVARCHAR(10) NULL
         , M_Company       NVARCHAR(45) NULL  
         , PickLOC         NVARCHAR(10)  NULL
         , SKUSize         NVARCHAR(10) NULL   
         , ORDUdef04       NVARCHAR(20) NULL 
         , PSKU            NVARCHAR(20)  NULL
         , Pqty            INT               
         , OrderKey        NVARCHAR(10)  NULL          
         , Loadkey         NVARCHAR(10)  NULL        
         , Salesman        NVARCHAR(30)  NULL        
         , Shipperkey      NVARCHAR(15)  NULL  
         , SDescr          NVARCHAR(150)  NULL 
         , UnitPrice       FLOAT
         , ORDUdef01       NVARCHAR(20) NULL
         , ORDUdef05       NVARCHAR(20) NULL
         , InvAmount       FLOAT
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
  
   INSERT INTO #PACKLIST25 ( c_Contact1    
                           , C_Addresses   
                           , OrdPmtTerm    
                           , OrdAddDate    
                           , M_Company     
                           , PickLOC       
                           , SKUSize       
                           , ORDUdef04     
                           , PSKU          
                           , Pqty          
                           , OrderKey      
                           , Loadkey       
                           , Salesman      
                           , Shipperkey    
                           , SDescr        
                           , UnitPrice     
                           , ORDUdef01     
                           , ORDUdef05     
                           , InvAmount     
                           , RecGrp        
                        )             
   SELECT ISNULL(OH.c_Contact1,''),(OH.C_address2 + OH.C_address3 + OH.C_address4),
                   ISNULL(OH.PmtTerm,''),CONVERT(NVARCHAR(10),OH.OrderDate,111),ISNULL(OH.M_Company,''),
                   PD.LOC,s.size,ISNULL(OH.TrackingNo,''),PD.SKU,PD.qty,OH.OrderKey,     --CS01
                   OH.Loadkey,OH.Salesman,OH.shipperkey,S.Descr,ORDDET.UnitPrice,ISNULL(OH.Userdefine01,''),
                   ISNULL(OH.Userdefine05,''),OH.InvoiceAmount,
                   (Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.LOC Asc)-1)/@n_NoOfLine 
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey 
                            AND PD.orderlinenumber = ORDDET.orderlinenumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey
   JOIN STORER STO WITH (NOLOCK) ON OH.shipperkey = STO.Storerkey                           
   WHERE PD.Orderkey = @c_getOrdKey--@c_orderkey                                --(CS01)
   AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END
   ORDER By PD.LOC
  
  
                   SELECT c_Contact1    
                           , C_Addresses   
                           , OrdPmtTerm    
                           , OrdAddDate    
                           , M_Company     
                           , PickLOC       
                           , SKUSize       
                           , ORDUdef04     
                           , PSKU          
                           , Pqty          
                           , OrderKey      
                           , Loadkey       
                           , Salesman      
                           , Shipperkey    
                           , SDescr        
                           , UnitPrice     
                           , ORDUdef01     
                           , ORDUdef05     
                           , InvAmount     
                           , RecGrp 
   FROM #PACKLIST25  
   ORDER BY PickLoc  
               
END



GO