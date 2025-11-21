SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store Procedure: isp_isp_PackListByCtn06                                   */  
/* Creation Date:                                                             */  
/* Copyright: IDS                                                             */  
/* Written by: CSCHONG                                                        */  
/*                                                                            */  
/* Purpose: SOS#368338- [CN Swire] New packinglist for Swire                  */  
/*        :                                                                   */  
/* Called By:                                                                 */  
/*                                                                            */  
/* PVCS Version: 1.0                                                          */  
/*                                                                            */  
/* Version: 1.0                                                               */  
/*                                                                            */  
/* Data Modifications:                                                        */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author    Ver.  Purposes                                      */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/******************************************************************************/  
  
CREATE PROC [dbo].[isp_PackListByCtn06] (
         @c_PickSlipNo NVARCHAR(10))  
AS  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 

BEGIN  
   DECLARE @n_continue 			INT 
      	, @n_starttcnt 		INT
    		, @b_success 			INT  
      	, @n_err 				INT 
      	, @c_errmsg 		 NVARCHAR(255)

		   , @c_ExecSQLStmt 		NVARCHAR(MAX)  
         , @c_ExecArguments   NVARCHAR(MAX) 
     	   
         , @n_Cnt             INT
         , @n_NoOfCarton      INT
         , @n_CartonNo        INT

         , @c_Logo1           NVARCHAR(60)
         , @c_Logo2           NVARCHAR(60)
         , @c_Logo3           NVARCHAR(60) 

         , @c_Orderkey        NVARCHAR(10)  
         , @c_LabelNo         NVARCHAR(20)
      	, @c_Storerkey 	   NVARCHAR(15)          	
      	, @c_Style 			   NVARCHAR(20)
      	, @c_Color           NVARCHAR(10)
      	, @c_Busr3			   NVARCHAR(30) 
      	, @c_Busr4 			   NVARCHAR(30) 
      	, @c_Size 			   NVARCHAR(5) 
         , @c_D_Userdefine03  NVARCHAR(18)  
         , @c_D_Userdefine05  NVARCHAR(18)  
         , @n_Qty             INT
 
   SET @n_continue      = 1
   SET @n_starttcnt     = @@TRANCOUNT
   SET @b_success       = 1
   SET @n_err           = 0
   SET @c_Errmsg        = ''

   SET @c_ExecSQLStmt   = ''  
   SET @c_ExecArguments = ''

   SET @n_Cnt           = 0
   SET @n_CartonNo      = 0
   SET @n_NoOfCarton    = 0

   SET @c_Logo1         = ''
   SET @c_Logo2         = ''
   SET @c_Logo3         = ''

   SET @c_Orderkey      = ''
   SET @c_LabelNo       = ''
   SET @c_Storerkey     = ''
   SET @c_Style         = ''
   SET @c_Color         = ''
   SET @c_Busr3         = ''
   SET @c_Busr4         = ''
   SET @c_Size          = ''
   SET @c_D_Userdefine03= ''
   SET @c_D_Userdefine05= ''
   SET @n_Qty           = 0

   CREATE Table #TempPackListByCtn06 (
   	           OrderKey 		      NVARCHAR(30) NULL 
               , ExternOrderkey 	   NVARCHAR(50) NULL  --tlting_ext
               , ConsigneeKey       NVARCHAR(30) NULL
               , ST_Company         NVARCHAR(45) NULL  
               , OrdNotes           NVARCHAR(250) NULL
               , Susr5      		   NVARCHAR(20) NULL
               , Susr4      		   NVARCHAR(20) NULL
               , ST_Address 		   NVARCHAR(200) NULL
               , ST_Contact  		   NVARCHAR(90) NULL
               , ST_State  		   NVARCHAR(45) NULL
               , ST_City    		   NVARCHAR(45) NULL
               , CartonNo 		      INT
               , PickSlipNo	      NVARCHAR(20) NULL
               , PQty      	      INT 
               , BuyerPO            NVARCHAR(20) NULL
               , SKUGroup  	      NVARCHAR(10) NULL
               , ItemClass          NVARCHAR(10) NULL
               , Price			      FLOAT
               , SKUSize            NVARCHAR(30) NULL
--               , NoOfCarton 	      INT NULL
    ) 

 


   INSERT INTO #TempPackListByCtn06 (
   	          OrderKey 
               , ExternOrderkey 	   
               , ConsigneeKey       
               , ST_Company         		                 
               , OrdNotes          
               , Susr5      		   
               , Susr4      		   
               , ST_Address 		  
               , ST_Contact  		  
               , ST_State 
               , ST_City  		   
               , PickSlipNo	     
               , CartonNo 		      
               , PQty 
               , BuyerPO
               , SKUGroup
               , ItemClass
               , Price
               , SKUSize)
   SELECT DISTINCT ORD.OrderKey
               , ORD.ExternOrderkey   
               , ORD.ConsigneeKey       
               , ST.Company          		                
               , (ORD.Notes + ' ' + Ord.Notes2) as OrdNotes           
               , CASE WHEN ISNULL(CL.long,'') <> '' THEN ST1.Susr5  ELSE ST1.susr4 END AS Susr5    		   
               , ST.Susr4      		   
               , (RTRIM(ST.Address1) + SPACE(2) + LTRIM(ST.Address2)) + (RTRIM(ST.Address3) + SPACE(2) + LTRIM(ST.Address4))  AS ST_Address 		  
               , (RTRIM(ST.Contact1) + SPACE(2) + RTRIM(LTRIM(ST.Contact2)) + '/' 
                  + RTRIM(ST.Phone1) + SPACE(2) + LTRIM(ST.Phone2) ) AS ST_Contact  		  
               , ST.State
               , ST.City   		   
               , PH.PickSlipNo	     
               , PDET.CartonNo 		      
               , SUM(PDET.Qty) AS PQty 
               , ORD.BuyerPO 
               , S.SKUGroup
               , S.ItemClass
               , SUM((S.Price*PDET.qty)) as Price
               , (RTRIM(s.sku) +'/'+ s.size) as SKUSize
   FROM ORDERS ORD  WITH (NOLOCK)
   JOIN STORER ST WITH (NOLOCK)
     ON (ST.StorerKey = ORD.consigneekey)
   JOIN STORER ST1 WITH (NOLOCK)
     ON (ST1.StorerKey = ORD.storerkey)  
   JOIN PACKHEADER PH WITH (NOLOCK) 
     ON (ORD.Orderkey = PH.Orderkey and ORD.Storerkey = PH.Storerkey)
   JOIN PACKDETAIL PDET WITH (NOLOCK) 
     ON (PDET.PickSlipNo = PH.PickSlipNo)
   JOIN SKU S WITH  (NOLOCK) 
     ON (PDET.Storerkey = S.Storerkey)
    AND (PDET.Sku = S.Sku)
    LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.long=ORD.Stop AND CL.listname = 'CBCODE'
    WHERE PH.PickSlipNo = @c_PickSlipNo 
GROUP BY ORD.ExternOrderkey   
               , ORD.ConsigneeKey       
               , ST.Company         
               , ORD.OrderKey 		      
               , ORD.BuyerPO           
               , ORD.Notes 
               , ORD.Notes2          
               , ST1.Susr5      		   
               , ST.Susr4      		   
               , ST.Address1 
               , ST.Address2 	
               , ST.Address3 
               , ST.Address4 	  
               , ST.Contact1
               , ST.Contact2  
               , ST.Phone1	
               , ST.Phone2	  
               , ST.State  
               , ST.City		   
               , PH.PickSlipNo	     
               , PDET.CartonNo 		      
               , S.SKUGroup
               , S.ItemClass
               , RTRIM(s.sku)
               , s.size
               ,ST1.SUSR4
               ,CL.long
                         

   SELECT *
   FROM #TempPackListByCtn06            
   ORDER BY ISNULL(CartonNo,0),ISNULL(skusize,'')         
          

   DROP TABLE #TempPackListByCtn06
END  

GO