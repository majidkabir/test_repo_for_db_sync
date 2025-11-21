SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store Procedure: isp_isp_PackListByCtn09                                   */  
/* Creation Date:05-Apr-2017                                                  */  
/* Copyright: IDS                                                             */  
/* Written by: CSCHONG                                                        */  
/*                                                                            */  
/* Purpose: WMS-1521-CN-Packing List for Columbia                             */  
/*        :                                                                   */  
/* Called By:  r_dw_packing_list_by_ctn09                                     */  
/*             copy from r_dw_packing_list_by_ctn06                           */
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
/* 13-Dec-2022  Mingle    1.2   WMS-21311 add new field(ML01)                 */
/******************************************************************************/  
  
CREATE PROC [dbo].[isp_PackListByCtn09] (
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
			, @n_maxcarton       INT
 
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

	SELECT @n_maxcarton = MAX(PD.CARTONNO)
	FROM PACKHEADER PH(NOLOCK)
	JOIN PACKDETAIL PD(NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
	WHERE PH.PickSlipNo = @c_PickSlipNo
	

   CREATE Table #TempPackListByCtn09 (
   	           OrderKey 		      NVARCHAR(30) NULL 
               , ExternOrderkey 	   NVARCHAR(50) NULL  --tlting_ext
               , ConsigneeKey       NVARCHAR(30) NULL
               , ORD_Company        NVARCHAR(45) NULL  
               , OrdNotes           NVARCHAR(250) NULL
               , Susr5      		   NVARCHAR(20) NULL
               , Susr4      		   NVARCHAR(20) NULL
               , ORD_Address 		   NVARCHAR(200) NULL
               , ORD_Contact  		NVARCHAR(90) NULL
               , ORD_State  		   NVARCHAR(45) NULL
               , ORD_City    		   NVARCHAR(45) NULL
               , CartonNo 		      INT
               , PickSlipNo	      NVARCHAR(20) NULL
               , PQty      	      INT 
               , BuyerPO            NVARCHAR(20) NULL
               , SKUGroup  	      NVARCHAR(10) NULL
               , ItemClass          NVARCHAR(10) NULL
               , Price			      FLOAT
               , SKUSize            NVARCHAR(30) NULL
					, BUSR1              NVARCHAR(10) NULL
--               , NoOfCarton 	      INT NULL
					, Refno					NVARCHAR(20) NULL
    ) 

 


   INSERT INTO #TempPackListByCtn09 (
   	          OrderKey 
               , ExternOrderkey 	   
               , ConsigneeKey       
               , ORD_Company         		                 
               , OrdNotes          
               , Susr5      		   
               , Susr4      		   
               , ORD_Address 		  
               , ORD_Contact  		  
               , ORD_State 
               , ORD_City  		   
               , PickSlipNo	     
               , CartonNo 		      
               , PQty 
               , BuyerPO
               , SKUGroup
               , ItemClass
               , Price
               , SKUSize
					, BUSR1
					, Refno)
   SELECT DISTINCT ORD.OrderKey
               , ORD.ExternOrderkey   
               , ORD.ConsigneeKey       
               , ORD.C_Company          		                
               , (ORD.Notes + ' ' + Ord.Notes2) as OrdNotes           
               , CASE WHEN ISNULL(CL.long,'') <> '' THEN ST1.Susr5  ELSE ST1.susr4 END AS Susr5    		   
               , ORD.C_Country   		   
               , (RTRIM(ORD.C_Address1) + SPACE(2) + LTRIM(ORD.C_Address2)) + (RTRIM(ORD.C_Address3) + SPACE(2) + LTRIM(ORD.C_Address4))  AS ORD_Address 		  
               , (RTRIM(ORD.C_Contact1) + SPACE(2) + RTRIM(LTRIM(ORD.C_Contact2)) + '/' 
                  + RTRIM(ORD.C_Phone1) + SPACE(2) + LTRIM(ORD.C_Phone2) ) AS ORD_Contact  		  
               , ORD.C_State
               , ORD.C_City   		   
               , PH.PickSlipNo	     
               , PDET.CartonNo 		      
               , SUM(PDET.Qty) AS PQty 
               , ORD.BuyerPO 
               , S.SKUGroup
               , S.ItemClass
               , SUM((S.Price*PDET.qty)) AS Price
               , (RTRIM(s.sku) +'/'+ s.size) AS SKUSize
               ,LEFT(S.BUSR1,10) 
					--, CASE WHEN PH.STATUS = '9' AND PDET.CARTONNO = @n_maxcarton THEN PDET.RefNo ELSE '' END AS Refno 
					, (SELECT TOP 1 PACKDETAIL.REFNO
						FROM PACKHEADER(NOLOCK)
						JOIN PACKDETAIL(NOLOCK) ON PackDetail.PickSlipNo = PackHeader.PickSlipNo
						WHERE PACKHEADER.PICKSLIPNO = @c_PickSlipNo
						AND PACKHEADER.STATUS = '9'
						AND PACKDETAIL.CARTONNO = @n_maxcarton)
   FROM ORDERS ORD  WITH (NOLOCK)
   JOIN STORER ST1 WITH (NOLOCK)
     ON (ST1.StorerKey = ORD.storerkey)  
   JOIN PACKHEADER PH WITH (NOLOCK) 
     ON (ORD.Orderkey = PH.Orderkey AND ORD.Storerkey = PH.Storerkey)
   JOIN PACKDETAIL PDET WITH (NOLOCK) 
     ON (PDET.PickSlipNo = PH.PickSlipNo)
   JOIN SKU S WITH  (NOLOCK) 
     ON (PDET.Storerkey = S.Storerkey)
    AND (PDET.Sku = S.Sku)
    LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.long=ORD.Stop AND CL.listname = 'CBCODE'
    WHERE PH.PickSlipNo = @c_PickSlipNo 
GROUP BY ORD.ExternOrderkey   
               , ORD.ConsigneeKey       
               , ORD.c_Company         
               , ORD.OrderKey 		      
               , ORD.BuyerPO           
               , ORD.Notes 
               , ORD.Notes2          
               , ST1.Susr5      		   
               , ORD.C_Country   
               , ORD.C_Address1 
               , ORD.C_Address2 	
               , ORD.C_Address3 
               , ORD.C_Address4 	  
               , ORD.C_Contact1
               , ORD.C_Contact2  
               , ORD.C_Phone1	
               , ORD.C_Phone2	  
               , ORD.C_State  
               , ORD.C_City		   
               , PH.PickSlipNo	     
               , PDET.CartonNo 		      
               , S.SKUGroup
               , S.ItemClass
               , RTRIM(s.sku)
               , s.size
               ,ST1.SUSR4
               ,CL.long
               ,LEFT(S.BUSR1,10)
					--, CASE WHEN PH.STATUS = '9' THEN PDET.RefNo ELSE '' END 
					,PH.STATUS
					,PDET.RefNo
                         

   SELECT *
   FROM #TempPackListByCtn09            
   ORDER BY ISNULL(CartonNo,0),ISNULL(skusize,'')         
          

   DROP TABLE #TempPackListByCtn09
END  

GO