SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_34_rdt                                   */              
/* Creation Date: 10-APR-2017                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-1586 - CN-ELLEDecor_PackingList                               */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_34_rdt                                       */              
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
  
CREATE PROC [dbo].[isp_Packing_List_34_rdt]             
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
  
         , @n_TTLPQty         INT   
         , @c_shippername     NVARCHAR(45)  
         , @c_Sku             NVARCHAR(20)  
         , @n_skuqty          INT
         , @c_OrdKey          NVARCHAR(10) 
         , @n_NoOfLine        INT  
         , @c_getOrdKey       NVARCHAR(10)
         , @n_pageno          INT
         , @c_PreSku          NVARCHAR(20)

		 SET @n_NoOfLine = 6
		 SET @c_getOrdKey = ''              
		 SET @n_PageNo = 0       
		 SET @n_TTLPQty = 1  
		 SET @c_PreSku = ''
  
  
 CREATE TABLE #PACKLIST34 
         ( c_Contact1      NVARCHAR(30) NULL 
         , C_Addresses     NVARCHAR(200) NULL
         , c_Phone1        NVARCHAR(18) NULL
         , c_Phone2        NVARCHAR(18) NULL
         , c_Company       NVARCHAR(45) NULL 
         , m_Company       NVARCHAR(45) NULL 
         , PickLOC         NVARCHAR(10)  NULL
         , SKUSize         NVARCHAR(10) NULL   
         , ORDUdef03       NVARCHAR(20) NULL 
         , PASKU           NVARCHAR(20)  NULL
         , Pqty            INT               
         , OrderKey        NVARCHAR(10)  NULL          
         , Loadkey         NVARCHAR(10)  NULL        
         , Shipperkey      NVARCHAR(30)  NULL        
         , ODQtyPick       INT  
         , RecGrp          INT
         , PageNo           INT 
         , TTLPQty          INT
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
  
   INSERT INTO #PACKLIST34 (
                             c_Contact1      
									 , C_Addresses     
									 , c_Phone1        
									 , c_Phone2       
									 , C_Company       
									 , m_Company   
									 , PickLOC         
									 , SKUSize         
									 , ORDUdef03       
									 , PASKU           
									 , Pqty            
									 , OrderKey        
									 , Loadkey         
									 , Shipperkey        
									 , ODQtyPick     
									 , RecGrp
									 , PageNo
                            , TTLPQty         
                           )             
   SELECT DISTINCT ISNULL(OH.c_Contact1,''),(OH.C_state+OH.C_City+OH.C_address1+OH.C_address2 + OH.C_address3 + OH.C_address4),
                   ISNULL(OH.C_Phone1,''),
                   ISNULL(OH.C_Phone2,''),
                   ISNULL(OH.C_Company,''),
                   ISNULL(OH.M_Company,''),PD.LOC,s.size,
                   ISNULL(OH.Userdefine03,''),
                   ORDDET.sku,SUM(PD.qty) AS qty,OH.OrderKey,
                   OH.Loadkey,OH.shipperkey,ORDDET.QtyPicked,
                   (Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY ORDDET.SKU Asc)-1)/@n_NoOfLine,0,0 
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey 
                            AND PD.orderlinenumber = ORDDET.orderlinenumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = ORDDET.SKU AND S.Storerkey=ORDDET.Storerkey
   --JOIN STORER STO WITH (NOLOCK) ON OH.shipperkey = STO.Storerkey  
   --LEFT JOIN FACILITY F WITH (NOLOCK) ON f.Facility=oh.Facility                       
   WHERE PD.Orderkey = @c_getOrdKey--@c_orderkey                                --(CS01)
   AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END
   GROUP BY ISNULL(OH.c_Contact1,''),(OH.C_state+OH.C_City+OH.C_address1+OH.C_address2 + OH.C_address3 + OH.C_address4),
                   ISNULL(OH.C_Phone1,''),
                   ISNULL(OH.C_Phone2,''),
                   ISNULL(OH.C_Company,''),
                   ISNULL(OH.M_Company,''),PD.LOC,s.size,
                   ISNULL(OH.Userdefine03,''),
                   ORDDET.sku,OH.OrderKey,
                   OH.Loadkey,OH.shipperkey,ORDDET.QtyPicked
   ORDER By OH.OrderKey,ORDDET.sku
   
   
      SET @n_TTLPQty = 1
   	
   	SELECT @n_TTLPQty = SUM(pqty)
   	FROM #PACKLIST34
   	WHERE orderkey = @c_getOrdKey
   	
   	
   	DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT PA34.Orderkey,PA34.PASKU   
   FROM   #PACKLIST34 PA34  
   WHERE orderkey = @c_getOrdKey 
   GROUP BY PA34.OrderKey,PA34.PASKU
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_Ordkey,@c_Sku    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
   	SET @n_skuqty = 1
   	
   	SELECT @n_skuqty = SUM(pqty)
   	FROM #PACKLIST34
   	WHERE orderkey = @c_Ordkey
   	AND PASKU = @c_Sku
   	
   	SET @n_pageno = @n_pageno + 1
   	
      UPDATE #PACKLIST34
      SET PageNo = @n_pageno
         ,TTLPQty = @n_TTLPQty
      WHERE orderkey=@c_Ordkey
      AND PASKU=@c_sku
   		
   		
   		WHILE @n_skuqty > 1
   		BEGIN
   			SET @n_pageno = @n_pageno + 1
   			
   			INSERT INTO #PACKLIST34 (  c_Contact1      
									          , C_Addresses     
												 , c_Phone1        
												 , c_Phone2       
												 , C_Company       
												 , m_Company   
												 , PickLOC         
												 , SKUSize         
												 , ORDUdef03       
												 , PASKU           
												 , Pqty            
												 , OrderKey        
												 , Loadkey         
												 , Shipperkey        
												 , ODQtyPick     
												 , RecGrp
												 , PageNo
												 , TTLPQty )
   			               
   					SELECT 	TOP 1      c_Contact1      
													, C_Addresses     
													, c_Phone1        
													, c_Phone2       
													, C_Company       
													, m_Company   
													, PickLOC         
													, SKUSize         
													, ORDUdef03       
													, PASKU           
													, Pqty            
													, OrderKey        
													, Loadkey         
													, Shipperkey        
													, ODQtyPick     
													, RecGrp
													, @n_pageno  
												   , @n_TTLPQty  
   		FROM #PACKLIST34
   		WHERE OrderKey=@c_OrdKey
   		AND PASKU = @c_sku	
   		ORDER BY PageNo		
   		
   		SET @n_skuqty = 	@n_skuqty - 1		        
   			
   		END
   		
   	
   	
   	
   FETCH NEXT FROM CUR_RESULT INTO @c_Ordkey,@c_Sku   
   END 
  
  
                   SELECT   c_Contact1      
									 , C_Addresses     
									 , c_Phone1        
									 , c_Phone2       
									 , C_Company       
									 , m_Company   
									 , PickLOC         
									 , SKUSize         
									 , ORDUdef03       
									 , PASKU           
									 , Pqty            
									 , OrderKey        
									 , Loadkey         
									 , Shipperkey        
									 , ODQtyPick     
									 , RecGrp  
									 , PageNo
									 , TTLPQty              
   FROM #PACKLIST34 
   ORDER BY Orderkey,PASKU,PageNo  
               
END



GO