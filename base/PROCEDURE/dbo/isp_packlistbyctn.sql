SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store Procedure: isp_isp_PackListByCtn                                     */  
/* Creation Date:05-Apr-2017                                                  */  
/* Copyright: IDS                                                             */  
/* Written by: CSCHONG                                                        */  
/*                                                                            */  
/* Purpose: WMS-1092-CN Panora Exceed Packing Modify Request                  */  
/*        :                                                                   */  
/* Called By:  r_dw_packing_list_by_ctn                                       */  
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
  
CREATE PROC [dbo].[isp_PackListByCtn] (
         @c_PickSlipNo NVARCHAR(10))  
AS  
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
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

   CREATE Table #TempPackListByCtn (
   	           OrderKey 		      NVARCHAR(10) NULL 
               , ExternOrderkey 	   NVARCHAR(30) NULL
               , ORD_Contact1  		NVARCHAR(30) NULL
               , ORD_Address1  	   NVARCHAR(45) NULL
               , C_Phone1           NVARCHAR(18) NULL
               , SKU                NVARCHAR(20) NULL
               , CartonNo 		      INT
               , LoadKey            NVARCHAR(20) NULL
               , PackQty    	      INT 
               , ORD_Company        NVARCHAR(45) NULL 
               , PackUOM3           NVARCHAR(10) NULL  
               , LabelNo            NVARCHAR(20) NULL
               , SDESCR     		   NVARCHAR(60) NULL
               , Stdnetwgt  		   FLOAT 
               , Stdcube    		   FLOAT
               , short      		   NVARCHAR(10) NULL 
               , grpbycarton	      NVARCHAR(10) NULL 
               , ByCartonNo         INT
               , sortbypackqty      NVARCHAR(10) NULL
    ) 

 


   INSERT INTO #TempPackListByCtn (
   	         OrderKey 		      
               , ExternOrderkey 	   
               , ORD_Contact1  		
               , ORD_Address1  	   
               , C_Phone1           
               , SKU                
               , CartonNo 		      
               , LoadKey            
               , PackQty    	       
               , ORD_Company        
               , PackUOM3             
               , LabelNo            
               , SDESCR     		   
               , Stdnetwgt  		    
               , Stdcube    		   
               , short      		   
               , grpbycarton	      
               , ByCartonNo
               ,sortbypackqty)
     SELECT ORDERS.OrderKey,   
         ORDERS.ExternOrderKey,   
         ORDERS.C_contact1,   
         ORDERS.C_Address1,   
         ORDERS.C_Phone1,   
         PackDetail.SKU, 
         PackDetail.CartonNo,   
         PackHeader.LoadKey,
         SUM(Packdetail.Qty) as PackQty ,
         ORDERS.C_Company, 
         PACK.PackUOM3,
			PackDetail.LabelNo,
			SKU.DESCR, 
         SKU.Stdnetwgt, 
         SKU.Stdcube,
         CLR.short AS short 
         ,ISNULL(CLR1.Short,'N') AS grpbycarton
         ,CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN PackDetail.CartonNo ELSE 1 END AS ByCartonNo  
         ,ISNULL(CLR2.Short,'N') AS sortbypackqty
    FROM ORDERS (NOLOCK)   
    JOIN PackDetail (NOLOCK) ON ( ORDERS.StorerKey = PackDetail.StorerKey )   
    JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo 
										AND Packheader.Orderkey = Orders.Orderkey 
										AND Packheader.Loadkey = Orders.Loadkey 
										AND Packheader.Consigneekey = Orders.Consigneekey )
    JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
    JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey ) 
    LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'   
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'PGBREAKBYCARTON'   
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR1.Short,'') <> 'N')  
  LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'SORTBYPACKQTY'   
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR2.Short,'') <> 'N')                                           
   WHERE ( RTRIM(PackHeader.OrderKey) IS NOT NULL AND RTRIM(PackHeader.OrderKey) <> '') and 
         ( Packheader.Pickslipno = @c_PickSlipNo)
GROUP BY ORDERS.OrderKey,   
         ORDERS.ExternOrderKey,   
         ORDERS.C_contact1,   
         ORDERS.C_Address1,   
         ORDERS.C_Phone1,   
         PackDetail.SKU, 
         PackDetail.CartonNo,   
         PackHeader.LoadKey,
         ORDERS.C_Company, 
         PACK.PackUOM3,
			PackDetail.LabelNo,
			SKU.DESCR,  
         SKU.Stdnetwgt, 
         SKU.Stdcube,
         CLR.short
        ,ISNULL(CLR1.Short,'N')
        ,ISNULL(CLR2.Short,'N')
   UNION ALL
  SELECT '' as OrderKey,   
         '' as ExternOrderKey,   
         MAX(ORDERS.C_contact1) as C_contact1,   
         MAX(ORDERS.C_Address1) as C_Address1,   
         MAX(ORDERS.C_Phone1) as C_Phone1,   
         PackDetail.SKU, 
         PackDetail.CartonNo,   
         PackHeader.LoadKey,
         SUM(Packdetail.Qty) as PackQty,
         MAX(Orders.C_Company) as C_Company, 
         PACK.PackUOM3,
			PackDetail.LabelNo,
			SKU.DESCR,    
         SKU.Stdnetwgt, 
         SKU.Stdcube,
         CLR.short AS short  
         ,ISNULL(CLR1.Short,'N') AS grpbycarton
         ,CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN PackDetail.CartonNo ELSE 1 END AS ByCartonNo
         ,ISNULL(CLR2.Short,'N') AS sortbypackqty
    FROM PackDetail (NOLOCK)    
    JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo ) 
    JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey ) 
    JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )   
    JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey ) 
    JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey ) 
    LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'   
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'PGBREAKBYCARTON'   
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR1.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'SORTBYPACKQTY'   
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_packing_list_by_ctn' AND ISNULL(CLR2.Short,'') <> 'N')                                     
   WHERE ( RTRIM(PackHeader.OrderKey) IS NULL OR RTRIM(PackHeader.OrderKey) = '') and 
         ( Packheader.Pickslipno = @c_PickSlipNo)
GROUP BY ORDERS.OrderKey,   
         ORDERS.ExternOrderKey,   
         ORDERS.C_contact1,   
         ORDERS.C_Address1,   
         ORDERS.C_Phone1,   
         PackDetail.SKU, 
         PackDetail.CartonNo,   
         PackHeader.LoadKey,
         ORDERS.C_Company, 
         PACK.PackUOM3,
			PackDetail.LabelNo,
			SKU.DESCR, 
         SKU.Stdnetwgt, 
         SKU.Stdcube,
         CLR.short  
        ,ISNULL(CLR1.Short,'N')
        ,ISNULL(CLR2.Short,'N')


                         

   SELECT *
   FROM #TempPackListByCtn            
   ORDER BY CASE WHEN sortbypackqty = 'Y' THEN PackQty ELSE '' END desc
                 ,LabelNo, SKU      
          

   DROP TABLE #TempPackListByCtn
END  

GO