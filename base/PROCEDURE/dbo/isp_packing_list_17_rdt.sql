SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_17_rdt                                   */              
/* Creation Date: 13-APR-2015                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: SOS#337558 - Skechers ECOM packing list report                    */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_17_rdt                                       */              
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
  
CREATE PROC [dbo].[isp_Packing_List_17_rdt]             
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
  
  
 CREATE TABLE #PACKLIST  
         ( MCompany        NVARCHAR(65) NULL 
         , Externorderkey  NVARCHAR(30) NULL 
         , Orderkey        NVARCHAR(20) NULL
         , loadkey         NVARCHAR(10) NULL
         , Userdef03       NVARCHAR(20) NULL 
         , Salesman        NVARCHAR(30) NULL
         , c_Phone1        NVARCHAR(18) NULL
         , c_Contact1      NVARCHAR(30) NULL
         , C_Addresses     NVARCHAR(200) NULL  
         , shippername     NVARCHAR(45)  NULL
         , ORD_Adddate     NVARCHAR(10)  NULL
         , PickLOC         NVARCHAR(10)  NULL
         , SKU             NVARCHAR(20)  NULL
         , Size            NVARCHAR(10)  NULL
         , Totalqty        INT          
         )  
  
   INSERT INTO #PACKLIST (MCompany, Externorderkey , Orderkey , loadkey  , Userdef03 , Salesman   , c_Phone1     
                            , c_Contact1 , C_Addresses , shippername  , ORD_Adddate  , PickLOC , SKU , Size  , Totalqty  ) 
   SELECT OH.M_Company,OH.ExternOrderkey,OH.Loadkey,OH.Orderkey,OH.Userdefine03,OH.Salesman,
       OH.C_Phone1,OH.c_Contact1,(OH.C_address1 + OH.C_address2 + OH.C_address3),
       ST.company,CONVERT(NVARCHAR(10),OH.Adddate,111),PD.LOC,PD.SKU,s.size,PD.qty
   FROM ORDERS OH WITH (NOLOCK)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU
   JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.Shipperkey
   WHERE PD.Orderkey = @c_orderkey
   AND PD.Caseid = @c_labelno
  
  
   
   SELECT MCompany, Externorderkey , loadkey  ,Orderkey ,  Userdef03 , Salesman   , c_Phone1     
        , c_Contact1 , C_Addresses , shippername  , ORD_Adddate  , PickLOC , SKU , Size  , Totalqty    
   FROM #PACKLIST  
   ORDER BY PickLoc,Sku  
               
END



GO