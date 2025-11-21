SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_86_rdt                                   */              
/* Creation Date: 15-OCT-2020                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-15428 - [KR] Levis ECOM Packing List (PB Report - NEW)        */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_86_rdt (Copy From r_dw_packing_list_33_rdt)  */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Packing_List_86_rdt]             
       (@c_Orderkey NVARCHAR(10),
        @c_labelno  NVARCHAR(20))              
AS            
BEGIN            
    SET NOCOUNT ON  
    SET ANSI_NULLS OFF  
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
  
  
 CREATE TABLE #PACKLIST86  
         ( c_company       NVARCHAR(45) NULL
         , c_Contact1      NVARCHAR(30) NULL 
         , C_Addresses     NVARCHAR(200) NULL
         , c_Phone1        NVARCHAR(18) NULL
         , c_Phone2        NVARCHAR(18) NULL
         , c_zip           NVARCHAR(18) NULL
         , M_Company        NVARCHAR(45) NULL 
         , Externorderkey  NVARCHAR(30) NULL 
         , PickLOC         NVARCHAR(10)  NULL
         , Style           NVARCHAR(20) NULL
         , SKUColor        NVARCHAR(10) NULL 
         , SKUSize         NVARCHAR(10) NULL   
         , ORDUdef01       NVARCHAR(20) NULL 
         , ORDDETUDef01    NVARCHAR(50) NULL
         , SKU             NVARCHAR(20)  NULL
         , Openqty         INT           
         , UnitPrice       Float
         , storename       NVARCHAR(60) NULL
         , UPC             NVARCHAR(20) NULL 
         , CUdf02          NVARCHAR(400) NULL 
         , ReturnAddress   NVARCHAR(400) NULL         
         , OrderKey        NVARCHAR(10)  NULL          
         , BuyerPO         NVARCHAR(20) NULL
         , SDescr          NVARCHAR(150) NULL
         , Altsku          NVARCHAR(20) NULL
         , BAddress1       NVARCHAR(45)  NULL   
         , Logo            NVARCHAR(60) null         
         )  
  
   INSERT INTO #PACKLIST86 (c_company       
                        , c_Contact1        
                        , C_Addresses      
                        , c_Phone1  
                        , c_phone2     
                        , c_zip        
                        , M_Company 
                        , Externorderkey      
                        , PickLOC                 
                        , Style 
                        , SKUColor          
                        , SKUSize                      
                        , ORDUdef01      
                        , ORDDETUDef01     
                        , SKU            
                        , openqty                  
                        , UnitPrice      
                        , storename      
                        , UPC    
                        , CUdf02
                        , ReturnAddress        
                        , OrderKey             
                        , BuyerPO
                        , SDescr
                        , Altsku
                        , BAddress1
                        , Logo)             
   SELECT DISTINCT ISNULL(OH.C_company,''),ISNULL(OH.c_Contact1,''),(OH.C_address1 + OH.C_address2 + OH.C_address3),
                   ISNULL(OH.C_Phone1,''),ISNULL(OH.C_Phone2,''),ISNULL(OH.c_zip,''),ISNULL(OH.M_Company,''),
                   OH.Externorderkey,PD.LOC,S.Style,s.color,s.size,
                   ISNULL(RTRIM(OH.Userdefine01),''),
                   CASE WHEN ISNULL(RTRIM(ORDDET.Userdefine01) + RTRIM(ORDDET.Userdefine02),'') = '' THEN
                             S.descr ELSE
                             (ISNULL(RTRIM(ORDDET.Userdefine01),'')+ ISNULL(RTRIM(ORDDET.Userdefine02),'')) END ,
                   PD.SKU,SUM(PD.qty),  
                   ORDDET.UnitPrice,
                     STO.Company,
                     COALESCE(S.AltSku,S.RetailSku,S.ManufacturerSku,U.UPC),                 
                      C2.notes,C2.Notes2,OH.OrderKey,OH.BuyerPO,s.DESCR,S.ALTSKU,STO.B_Address1,STO.Logo               
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = ORDDET.Orderkey AND PD.SKU = ORDDET.SKU AND PD.OrderLineNumber = ORDDET.OrderLineNumber 
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey
   JOIN STORER STO WITH (NOLOCK) ON OH.Storerkey = STO.Storerkey                           
   LEFT JOIN UPC U WITH (NOLOCK) ON U.Storerkey = PD.storerkey and u.sku=PD.sku
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Listname = 'UAEPLOCN' AND C1.Storerkey = OH.Storerkey AND C1.Storerkey='UA'
   LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.Listname = 'UAPICLIST' AND C2.Storerkey = OH.Storerkey AND C2.Storerkey='UA'                            
   WHERE PD.Orderkey = @c_orderkey
   AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END
   Group By 
   ISNULL(OH.C_company,''),
        ISNULL(OH.c_Contact1,''),
        (OH.C_address1 + OH.C_address2 + OH.C_address3),
        ISNULL(OH.C_Phone1,''),
        ISNULL(OH.C_Phone2,''),
        ISNULL(OH.c_zip,''),
        ISNULL(OH.M_Company,''),
        OH.Externorderkey,
        PD.LOC,
        S.Style,
        s.color,
        s.size,
        ISNULL(RTRIM(OH.Userdefine01),''),
        CASE WHEN ISNULL(RTRIM(ORDDET.Userdefine01) + RTRIM(ORDDET.Userdefine02),'') = '' THEN
         S.descr ELSE
                (ISNULL(RTRIM(ORDDET.Userdefine01),'')+ ISNULL(RTRIM(ORDDET.Userdefine02),'')) END ,
        PD.SKU,
        ORDDET.UnitPrice,
        STO.Company,
        COALESCE(S.AltSku,S.RetailSku,S.ManufacturerSku,U.UPC),
        C2.notes,
        C2.Notes2,
        OH.OrderKey,
        OH.BuyerPO,
        s.DESCR,
        S.ALTSKU,STO.B_Address1,STO.Logo 
   
  
   
                   SELECT c_company       
                        , c_Contact1        
                        , C_Addresses      
                        , c_Phone1  
                        , c_phone2     
                        , c_zip        
                        , M_Company 
                        , Externorderkey       
                        , PickLOC                 
                        , Style 
                        , SKUColor          
                        , SKUSize                      
                        , ORDUdef01      
                        , ORDDETUDef01     
                        , SKU            
                        , openqty                  
                        , UnitPrice      
                        , ISNULL(storename,'') AS storename     
                        , UPC    
                        , ISNULL(CUdf02,'') AS cudf02
                        , ReturnAddress                               
                        , OrderKey                                   
                        , BuyerPO
                        , SDescr
                        , Altsku
                        , BAddress1  
                        , Logo       
   FROM #PACKLIST86  
   ORDER BY PickLoc  
               
END



GO