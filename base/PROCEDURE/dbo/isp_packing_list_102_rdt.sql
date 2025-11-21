SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_102_rdt                                  */              
/* Creation Date: 21-Jun-2021                                                 */              
/* Copyright: IDS                                                             */              
/* Written by:                                                                */              
/*                                                                            */              
/* Purpose: WMS-17251 - [CN]BoyLondon_PackingListCR                           */  
/*          Copied from isp_Packing_List_61_rdt                               */
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_102_rdt                                      */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */    
/*05/10/2019    WLCHOOI   1.0   WMS-9022 - Change logic of ExtLineNo (WL01)   */
/*21/06/2021    Mingle    1.1   WMS-17251 - Change logic of NoOfLine (ML01)   */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Packing_List_102_rdt]             
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

 SET @n_NoOfLine = 7 --ML01
 SET @c_getOrdKey = ''                --(CS01)
  
  
 CREATE TABLE #PACKLIST102 
         ( c_Contact1      NVARCHAR(30) NULL 
         , C_Addresses     NVARCHAR(200) NULL
         , c_Phone1        NVARCHAR(18) NULL
         , Extlineno       NVARCHAR(18) NULL
         , C_Company       NVARCHAR(45) NULL 
         , OrdLinenumber   NVARCHAR(10) NULL 
         , PickLOC         NVARCHAR(10)  NULL
         , SKUSize         NVARCHAR(10) NULL   
         , ORDUdef01       NVARCHAR(20) NULL 
         , PASKU           NVARCHAR(20)  NULL
         , Pqty            INT               
         , OrderKey        NVARCHAR(10)  NULL          
         , Loadkey         NVARCHAR(10)  NULL        
         , Salesman        NVARCHAR(30)  NULL        
         , OrdDate         NVARCHAR(10)  NULL  
         , SKUStyle        NVARCHAR(10)  NULL
         , ODUdef01        NVARCHAR(40)  NULL
         , ODUdef02        NVARCHAR(40)  NULL
         , OHNotes2        NVARCHAR(100) NULL
         , InvAmt          FLOAT NULL
         , FPhone2         NVARCHAR(18) NULL
         , UnitPrice       FLOAT NULL
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
  
   INSERT INTO #PACKLIST102 (  c_Contact1      
                            , C_Addresses     
                            , c_Phone1        
                            , Extlineno       
                            , C_Company       
                            , OrdLinenumber   
                            , PickLOC         
                            , SKUSize         
                            , ORDUdef01       
                            , PASKU           
                            , Pqty            
                            , OrderKey        
                            , Loadkey         
                            , Salesman        
                            , OrdDate
                            , SKUStyle        
                            , ODUdef01
                            , ODUdef02          
                            , OHNotes2        
                            , InvAmt          
                            , FPhone2         
                            , UnitPrice       
                            , RecGrp          
                           )             
   SELECT ISNULL(OH.c_Contact1,''),(OH.C_state+OH.C_City+OH.C_address1+OH.C_address2 + OH.C_address3 + OH.C_address4),
                   ISNULL(OH.C_Phone1,''),
                   --CASE WHEN Len(ORDDET.Externlineno)> 4 THEN SUBSTRING(ORDDET.Externlineno,0,(Len(ORDDET.Externlineno)-2)) ELSE '' END ExtLineno, --WL01
                   ISNULL(OH.M_Company,''),   --WL01
                   ISNULL(OH.C_Company,''),
                   SUBSTRING (ORDDET.Orderlinenumber,3,3),PD.LOC,s.size,
                   ISNULL(OH.Userdefine01,''),
                   S.AltSKU,PD.qty,OH.OrderKey,
                   OH.Loadkey,OH.Salesman,CONVERT(NVARCHAR(10),OH.OrderDate,103) AS ORDDate,
                   S.style,ORDDET.userdefine01,ORDDET.userdefine02,
                   CASE WHEN ISNULL(OH.Notes2,'') <> '' THEN OH.Notes2 ELSE '0' END AS OHNotes2,
                   (Convert(decimal(18,2),OH.Invoiceamount)),ISNULL(f.Phone2,''),ORDDET.UnitPrice,
                   (Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.LOC Asc)-1)/@n_NoOfLine 
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey 
                            AND PD.orderlinenumber = ORDDET.orderlinenumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey
   JOIN STORER STO WITH (NOLOCK) ON OH.shipperkey = STO.Storerkey  
   LEFT JOIN FACILITY F WITH (NOLOCK) ON f.Facility=oh.Facility                       
   WHERE PD.Orderkey = @c_getOrdKey--@c_orderkey                                --(CS01)
   AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END
   ORDER By PD.LOC
  
  
		SELECT     c_Contact1      
					, C_Addresses     
					, c_Phone1        
					, Extlineno       
					, C_Company       
					, OrdLinenumber   
					, PickLOC         
					, SKUSize         
					, ORDUdef01       
					, PASKU           
					, Pqty            
					, OrderKey        
					, Loadkey         
					, Salesman        
					, OrdDate   
					, SKUStyle        
					, ODUdef01
					, ODUdef02          
					, OHNotes2        
					, InvAmt          
					, FPhone2         
					, UnitPrice       
					, RecGrp          
			FROM #PACKLIST102  
			ORDER BY PickLoc  
               
END

GO