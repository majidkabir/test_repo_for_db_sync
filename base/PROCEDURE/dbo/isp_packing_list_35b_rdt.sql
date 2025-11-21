SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_35b_rdt                                  */              
/* Creation Date: 12-APR-2017                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-6223-CN-Victoria_Secret ECOM - Packing List                   */  
/*          refer WMS-1622. copy from isp_Packing_List_35_rdt                 */
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_35b_rdt                                      */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */   
/* 21-JUN-2017  CSCHONG   1.0   WMS-1622-revise column mapping (CS01)         */ 
/* 13-JUL-2017  CSCHONG   1.1   Merge with Chen version                       */
/* 26-Apr-2018  CSCHONG   1.2   WMS-4494 - Fix grrouping issue (CS02)         */
/* 02-Jan-2020  WLChooi   1.3   WMS-11677 - Add new filter (WL01)             */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Packing_List_35b_rdt]             
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
         , @n_cntline         INT
         , @n_maxrecgrp       INT

   SET @n_NoOfLine = 5
   SET @c_getOrdKey = ''   
   SET @n_cntline = 1 
   SET @n_maxrecgrp = 1
    
   CREATE TABLE #PACKLIST35 
           ( [ID]            [INT]  IDENTITY(1,1) NOT NULL,
             c_Contact1      NVARCHAR(30) NULL 
           , C_Addresses     NVARCHAR(200) NULL
           , c_state         NVARCHAR(18) NULL
           , c_city          NVARCHAR(18) NULL
           , c_zip           NVARCHAR(18) NULL 
           , m_Company       NVARCHAR(45) NULL 
           , OrdDate         DATETIME NULL
           , SKUSize         NVARCHAR(10) NULL   
           , SColor          NVARCHAR(20) NULL 
           , PASKU           NVARCHAR(20)  NULL
           , Pqty            INT  NULL             
           , OrderKey        NVARCHAR(10)  NULL          
           , ODUDF01         NVARCHAR(18)  NULL        
           , ODUDF02         NVARCHAR(18)  NULL        
           , Unitprice       FLOAT  DEFAULT(0.00)
           , OHUdf01         NVARCHAR(18) NULL
           , RecGrp          INT
           , BUSR1           NVARCHAR(30)  NULL         --CS01
           , BUSR2           NVARCHAR(80)  NULL         --CS01
           )  
   
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
   
   INSERT INTO #PACKLIST35 (
                  c_Contact1      
									, C_Addresses     
									, c_state        
									, c_city          
									, c_zip           
									, m_Company       
									, OrdDate         
									, SKUSize        
									, SColor          
									, PASKU           
									, Pqty                           
									, OrderKey                 
									, ODUDF01               
									, ODUDF02         
									, Unitprice            
									, OHUdf01 
                  , RecGrp
                  , BUSR2, BUSR1)            --CS01         
   SELECT ISNULL(OH.c_Contact1,''),
         (ISNULL(OH.C_address2,'') + ISNULL(OH.C_address3,'') + ISNULL(OH.C_address4,'')), 
          ISNULL(OH.C_state,''),ISNULL(OH.C_City,'') ,ISNULL(OH.C_zip,''),
          ISNULL(OH.M_Company,''),
          OH.OrderDate,s.size,
          s.color,s.sku,PD.qty,OH.OrderKey,
          '','',
          ORDDET.UnitPrice,OH.UserDefine01
          ,((Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.Orderkey,s.sku,s.color,s.size Asc)-1)/@n_NoOfLine)+1 --CS02
          , CASE WHEN ISNULL(ORDDET.notes,'') <> '' THEN ISNULL(ORDDET.notes,'')  ELSE ISNULL(S.busr2,'')  END             --CS01 
          ,ISNULL(S.busr1,'')                                                                         --CS01
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN (select PD.OrderKey , PD.OrderLineNumber , sum(PD.Qty) [qty] , '' [Caseid]
         from PICKDETAIL(nolock) PD 
	      where PD.Orderkey = @c_getOrdKey
	      group by PD.OrderKey , PD.OrderLineNumber
        ) PD
   ON PD.Orderkey = OH.Orderkey 
   AND PD.orderlinenumber = ORDDET.orderlinenumber                         
   JOIN SKU S WITH (NOLOCK) ON S.SKU = ORDDET.SKU AND S.Storerkey=ORDDET.Storerkey     
   JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'ALLOWPRINT' AND CL.Storerkey = OH.Storerkey AND CL.Code = OH.Salesman  --WL01           
   WHERE PD.Orderkey = @c_getOrdKey
   --AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END
   ORDER By OH.OrderKey,s.sku,s.color,s.size
	 
	 SELECT @n_maxrecgrp = MAX(recgrp)
	 FROM #PACKLIST35
  
   SELECT @n_cntline = COUNT(1)
   FROM #PACKLIST35
   WHERE RecGrp=@n_maxrecgrp
   
   WHILE @n_cntline < @n_NoOfLine
   BEGIN
   	 INSERT INTO #PACKLIST35 (m_Company,OrderKey,OHUdf01,RecGrp)
   	 SELECT TOP 1 m_Company,OrderKey,OHUdf01,RecGrp
   	 FROM #PACKLIST35
   	 WHERE RecGrp=@n_maxrecgrp
   	 
   	 SET @n_cntline = @n_cntline + 1     	
   END
  
   SELECT   ISNULL(c_Contact1,'')  
	 				, ISNULL(C_Addresses ,'')     
	 				, ISNULL(c_state ,'')        
	 				, ISNULL(c_city,'')           
	 				, ISNULL(c_zip ,'')           
	 				, m_Company       
	 				, ISNULL(OrdDate ,'')         
	 				, ISNULL(SKUSize ,'')        
	 				, ISNULL(SColor ,'')          
	 				, ISNULL(PASKU ,'')           
	 				, ISNULL(Pqty ,'')                           
	 				, ISNULL(OrderKey ,'')                 
	 				, ISNULL(ODUDF01 ,'')               
	 				, ISNULL(ODUDF02,'') AS ODUDF02         
	 				, ISNULL(Unitprice,0) AS Unitprice  
	 				, ISNULL(OHUdf01,0)     
	 				,RecGrp 
	 				,BUSR1,BUSR2                        --CS01
   FROM #PACKLIST35 
   ORDER BY ID          --CS02 Start               
END



GO