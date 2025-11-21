SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


 
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_33_rdt                                   */              
/* Creation Date: 17-FEB-2017                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-1083 - KR_UA_ECOM_PACKING_LIST                                */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_33_rdt (Copy From r_dw_packing_list_20_rdt)  */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */
/* 04-08-2015   CSCHONg   1.0   Add new field (CS01)                          */  
/* 13-08-2015   CSCHONG   1.1   change the mapping logic (CS02)               */   
/* 12-01-2016   CSCHONG   1.2   Change the mapping logic (CS03)               */
/* 23-10-2018   SPChin    1.3   INC0437349 - Add SUM QTY And Filter           */      
/*                                           By OrderLineNumber               */
/* 28-Jan-2019  TLTING_ext 1.4  enlarge externorderkey field length           */
/******************************************************************************/     
  
CREATE   PROC [dbo].[isp_Packing_List_33_rdt]             
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
         , @c_Externorderkey  NVARCHAR(50)   --tlting_ext
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
  
  
 CREATE TABLE #PACKLIST33  
         ( c_company       NVARCHAR(45) NULL
         , c_Contact1      NVARCHAR(30) NULL 
         , C_Addresses     NVARCHAR(200) NULL
         , c_Phone1        NVARCHAR(18) NULL
         , c_Phone2        NVARCHAR(18) NULL
         , c_zip           NVARCHAR(18) NULL
         , M_Company        NVARCHAR(45) NULL 
         , Externorderkey  NVARCHAR(50) NULL   --tlting_ext
         , PickLOC         NVARCHAR(10)  NULL
         , Style           NVARCHAR(20) NULL
         , SKUColor        NVARCHAR(10) NULL 
         , SKUSize         NVARCHAR(10) NULL   
         , ORDUdef01       NVARCHAR(20) NULL 
         , ORDDETUDef01    NVARCHAR(18) NULL
         , SKU             NVARCHAR(20)  NULL
         , Openqty         INT           
         , UnitPrice       Float
         , storename       NVARCHAR(60) NULL
         , UPC             NVARCHAR(20) NULL 
         , CUdf02          NVARCHAR(400) NULL 
         , ReturnAddress   NVARCHAR(400) NULL          --(CS02)
         , OrderKey        NVARCHAR(10)  NULL          --(CS02)
         , BuyerPO         NVARCHAR(20) NULL
         , SDescr          NVARCHAR(150) NULL
         , Altsku           NVARCHAR(20) NULL
--         , SAddress1       NVARCHAR(45)  NULL        --(CS01)
--         , SZip            NVARCHAR(45)  NULL        --(CS01)
--         , SContact1       NVARCHAR(30)  NULL        --(CS01) 
--         , SPhone1         NVARCHAR(18)  NULL        --(CS01)   
         )  
  
   INSERT INTO #PACKLIST33 (c_company       
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
                        , ReturnAddress          --(CS02) 
                        , OrderKey              --(CS02)
                        , BuyerPO
                        , SDescr
                        ,Altsku)
--                        , SAddress1             --(CS01) 
--                        , SZip                  --(CS01)
--                        , SContact1             --(CS01) 
--                        , SPhone1 )             --(CS01)
   SELECT DISTINCT ISNULL(OH.C_company,''),ISNULL(OH.c_Contact1,''),(OH.C_address1 + OH.C_address2 + OH.C_address3),
                   ISNULL(OH.C_Phone1,''),ISNULL(OH.C_Phone2,''),ISNULL(OH.c_zip,''),ISNULL(OH.M_Company,''),
                   OH.Externorderkey,PD.LOC,S.Style,s.color,s.size,
                   ISNULL(OH.Userdefine01,''),
                   CASE WHEN ISNULL(ORDDET.Userdefine01 + ORDDET.Userdefine02,'') = '' THEN
                             S.descr ELSE
                             (ISNULL(ORDDET.Userdefine01,'')+ ISNULL(ORDDET.Userdefine02,'')) END ,
                   PD.SKU,SUM(PD.qty),	--INC0437349 
		   ORDDET.UnitPrice,
                     C2.UDF01,
                     COALESCE(S.AltSku,S.RetailSku,S.ManufacturerSku,U.UPC),
                      C2.notes,C2.Notes2,OH.OrderKey,OH.BuyerPO,s.DESCR,S.ALTSKU--STO.Address1,STO.Zip,STO.Contact1,STO.Phone1          --(CS01)  --(CS02)               
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   --JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey AND PD.SKU = ORDDET.SKU                                                   --INC0437349
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = ORDDET.Orderkey AND PD.SKU = ORDDET.SKU AND PD.OrderLineNumber = ORDDET.OrderLineNumber --INC0437349
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey
   JOIN STORER STO WITH (NOLOCK) ON OH.Storerkey = STO.Storerkey                           --(CS01)
   LEFT JOIN UPC U WITH (NOLOCK) ON U.Storerkey = PD.storerkey AND u.sku=PD.sku
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Listname = 'UAEPLOCN' AND C1.Storerkey = OH.Storerkey AND C1.Storerkey='UA'
   LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.Listname = 'UAPICLIST' AND C2.Storerkey = OH.Storerkey AND C2.Storerkey='UA'
                                     --  AND C2.long = OH.UserDefine03 
   WHERE PD.Orderkey = @c_orderkey
   AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END
   --INC0437349 Start
   GROUP BY 
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
        ISNULL(OH.Userdefine01,''),
        CASE WHEN ISNULL(ORDDET.Userdefine01 + ORDDET.Userdefine02,'') = '' THEN
        	S.descr ELSE
                (ISNULL(ORDDET.Userdefine01,'')+ ISNULL(ORDDET.Userdefine02,'')) END ,
        PD.SKU,
	ORDDET.UnitPrice,
        C2.UDF01,
        COALESCE(S.AltSku,S.RetailSku,S.ManufacturerSku,U.UPC),
        C2.notes,
        C2.Notes2,
        OH.OrderKey,
        OH.BuyerPO,
        s.DESCR,
        S.ALTSKU
   --INC0437349 End
  
   
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
                        , ReturnAddress                               --(CS02)
                        , OrderKey                                    --(CS02)
                        , BuyerPO
                        , SDescr
                        , Altsku
                        --,SAddress1,SZip,SContact1,SPhone1          --(CS01)  --(CS02) 
   FROM #PACKLIST33  
   ORDER BY PickLoc  
               
END



GO