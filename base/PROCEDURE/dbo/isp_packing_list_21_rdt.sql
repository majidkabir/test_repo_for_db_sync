SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_21_rdt                                   */              
/* Creation Date: 01-FEB-2016                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: SOS#362146 - Skechers ECOM packing list report                    */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_21_rdt                                       */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */    
/* 05-Aug-2016  CSCHONG   1.0   Add logic to support RDT and ECOM EXCEED(CS01)*/  
/* 10-Nov-2016  SHONG     1.1   Performance Tuning  (SWT01)                   */
/* 11-Nov-2017  CSCHONG   1.2   Remove case (CS02)                            */
/* 27-Oct-2021  MINGLE    1.3   Modify logic (ML01)                           */
/* 20-Dec-2021  MINGLE    1.4   Add new mapping (ML02)                        */
/* 20-DEC-2021  Mingle    1.4   DevOps Combine Script                         */
/******************************************************************************/     
CREATE PROC [dbo].[isp_Packing_List_21_rdt]             
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
  
  
 --CREATE TABLE #PACKLIST21 
 --        ( c_Contact1      NVARCHAR(30) NULL 
 --        , C_Addresses     NVARCHAR(200) NULL
 --        , c_Phone1        NVARCHAR(18) NULL
 --        , c_Phone2        NVARCHAR(18) NULL
 --        , M_Company       NVARCHAR(45) NULL 
 --        , Externorderkey  NVARCHAR(30) NULL 
 --        , PickLOC         NVARCHAR(10)  NULL
 --        , SKUSize         NVARCHAR(10) NULL   
 --        , ORDUdef03       NVARCHAR(20) NULL 
 --        , PSKU            NVARCHAR(20)  NULL
 --        , Pqty            INT               
 --        , OrderKey        NVARCHAR(10)  NULL          
 --        , Loadkey         NVARCHAR(10)  NULL        
 --        , Salesman        NVARCHAR(30)  NULL        
 --        , Shipperkey      NVARCHAR(15)  NULL  
 --        , SCompany        NVARCHAR(45)  NULL 
 --        , RecGrp          INT
 --        )  
     
         
   /*CS01 Start*/
   
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
              WHERE Orderkey = @c_Orderkey)
   BEGIN
   	SET @c_getOrdKey = @c_Orderkey 
   END           
   ELSE
   BEGIN
   	--SELECT DISTINCT @c_getOrdKey = OrderKey
   	--FROM PackHeader AS ph WITH (NOLOCK)
   	--WHERE ph.PickSlipNo=@c_Orderkey
      --  (SWT01) 
   	SELECT TOP 1 
   	      @c_getOrdKey = OrderKey
   	FROM PackHeader AS ph WITH (NOLOCK)
   	WHERE ph.PickSlipNo=@c_Orderkey
   	
   END 	
   
   /*CS01 END*/      
   /*CS02 Start*/
   IF @c_labelno <> ''
   BEGIN
   --INSERT INTO #PACKLIST21 (
   --                       c_Contact1        
   --                     , C_Addresses      
   --                     , c_Phone1  
   --                     , c_phone2     
   --                     , M_Company 
   --                     , Externorderkey      
   --                     , PickLOC                         
   --                     , SKUSize                      
   --                     , ORDUdef03          
   --                     , PSKU            
   --                     , Pqty                  
   --                     , OrderKey             
   --                     , Loadkey             
   --                     , Salesman                  
   --                     , Shipperkey             
   --                     , SCompany 
   --                     , RecGrp)  
                                  
   SELECT c_Contact1     = CASE WHEN OH.ECOM_Platform IN ( 'PDD','TM') THEN '' ELSE ISNULL(OH.c_Contact1,'') END,
          C_Addresses    = CASE WHEN OH.ECOM_Platform IN ( 'PDD','TM') THEN '' ELSE (OH.C_address2 + OH.C_address3 + OH.C_address4) END,
          c_Phone1       = ISNULL(OH.C_Phone1,''),
          c_phone2       = CASE WHEN OH.ECOM_Platform IN ( 'PDD','TM') THEN '' ELSE ISNULL(OH.C_Phone2,'') END,
          M_Company      = ISNULL(OH.M_Company,''),
          Externorderkey =  OH.Externorderkey,
          PickLOC        =  PD.LOC,
          SKUSize        =  s.size,
          ORDUdef03      =  ISNULL(OH.Userdefine03,''),
          PSKU           =  PD.SKU,
          Pqty           =  PD.qty,
          OrderKey       =  OH.OrderKey,
          Loadkey        =  OH.Loadkey,
          --Salesman       =  OH.Salesman,
          Salesman       =  CASE WHEN OH.Salesman = 'PDD' THEN '' ELSE OH.Salesman END,   --ML01
          Shipperkey     =  OH.shipperkey,
          SCompany       =  STO.company,
          RecGrp         =  (Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.LOC Asc)-1)/@n_NoOfLine,
          clshort        =  CASE WHEN OH.ECOM_Platform = CL.Code THEN CL.Short ELSE '' END   --ML02
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = ORDDET.Orderkey 
                            AND PD.orderlinenumber = ORDDET.orderlinenumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey
   JOIN STORER STO WITH (NOLOCK) ON OH.shipperkey = STO.Storerkey 
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'SKEPLAT' AND CL.Storerkey = OH.StorerKey  --ML02                     
   WHERE OH.Orderkey = @c_getOrdKey  --(SWT01) 
    -- AND PD.Orderkey = @c_getOrdKey  --@c_orderkey  --(CS01) 
     --AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END
     AND PD.Caseid =  @c_labelno
   ORDER By PD.LOC
   END
   ELSE
   BEGIN
   	--INSERT INTO #PACKLIST21 (
    --                      c_Contact1        
    --                    , C_Addresses      
    --                    , c_Phone1  
    --                    , c_phone2     
    --                    , M_Company 
    --                    , Externorderkey      
    --                    , PickLOC                         
    --                    , SKUSize                      
    --                    , ORDUdef03          
    --                    , PSKU            
    --                    , Pqty                  
    --                    , OrderKey             
    --                    , Loadkey             
    --                    , Salesman                  
    --                    , Shipperkey             
    --                    , SCompany 
    --                    , RecGrp)  
                                  
    SELECT c_Contact1     = CASE WHEN OH.ECOM_Platform IN ( 'PDD','TM') THEN '' ELSE ISNULL(OH.c_Contact1,'') END,
          C_Addresses    = CASE WHEN OH.ECOM_Platform IN ( 'PDD','TM') THEN '' ELSE (OH.C_address2 + OH.C_address3 + OH.C_address4) END,
          c_Phone1       = ISNULL(OH.C_Phone1,''),
          c_phone2       = CASE WHEN OH.ECOM_Platform IN ( 'PDD','TM') THEN '' ELSE ISNULL(OH.C_Phone2,'') END,
          M_Company      = ISNULL(OH.M_Company,''),
          Externorderkey =  OH.Externorderkey,
          PickLOC        =  PD.LOC,
          SKUSize        =  s.size,
          ORDUdef03      =  ISNULL(OH.Userdefine03,''),
          PSKU           =  PD.SKU,
          Pqty           =  PD.qty,
          OrderKey       =  OH.OrderKey,
          Loadkey        =  OH.Loadkey,
          --Salesman       =  OH.Salesman,
          Salesman       =  CASE WHEN OH.Salesman = 'PDD' THEN '' ELSE OH.Salesman END,   --ML01
          Shipperkey     =  OH.shipperkey,
          SCompany       =  STO.company,
          RecGrp         =  (Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.LOC Asc)-1)/@n_NoOfLine,
          clshort        =  CASE WHEN OH.ECOM_Platform = CL.Code THEN CL.Short ELSE '' END   --ML02 
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = ORDDET.Orderkey 
                            AND PD.orderlinenumber = ORDDET.orderlinenumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey
   JOIN STORER STO WITH (NOLOCK) ON OH.shipperkey = STO.Storerkey   
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'SKEPLAT' AND CL.Storerkey = OH.StorerKey  --ML02                        
   WHERE OH.Orderkey = @c_getOrdKey  --(SWT01) 
    -- AND PD.Orderkey = @c_getOrdKey  --@c_orderkey  --(CS01) 
     --AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END
     --AND PD.Caseid =  @c_labelno
   ORDER By PD.LOC
   END	
  
  
   --SELECT c_Contact1        
   --, C_Addresses      
   --, c_Phone1  
   --, c_phone2     
   --, M_Company 
   --, Externorderkey      
   --, PickLOC                         
   --, SKUSize                      
   --, ORDUdef03          
   --, PSKU            
   --, Pqty                  
   --, OrderKey             
   --, Loadkey             
   --, Salesman                  
   --, Shipperkey             
   --, SCompany
   --, RecGrp
   --FROM #PACKLIST21  
   --ORDER BY PickLoc  
               
END



GO