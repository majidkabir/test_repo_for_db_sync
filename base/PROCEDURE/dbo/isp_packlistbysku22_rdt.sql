SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PackListBySku22_rdt                                 */
/* Creation Date: 09-Dec-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18499 - CN SWIRE B2B & B2C Packing List                 */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_sku22_rdt                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 09-Dec-2021 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListBySku22_rdt]
            @c_Pickslipno      NVARCHAR(10)
          , @c_Type            NVARCHAR(10) = 'M'
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   --B2B part copy from isp_PackListByCtn06
   --B2B START
   DECLARE @n_continue 			INT 
      	, @n_starttcnt 		INT
    		, @b_success 			INT  
      	, @n_err 				INT 
      	, @c_errmsg 		   NVARCHAR(255)

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

   SET @n_continue       = 1
   SET @n_starttcnt      = @@TRANCOUNT
   SET @b_success        = 1
   SET @n_err            = 0
   SET @c_Errmsg         = ''
                         
   SET @c_ExecSQLStmt    = ''  
   SET @c_ExecArguments  = ''
                         
   SET @n_Cnt            = 0
   SET @n_CartonNo       = 0
   SET @n_NoOfCarton     = 0
                         
   SET @c_Logo1          = ''
   SET @c_Logo2          = ''
   SET @c_Logo3          = ''
                         
   SET @c_Orderkey       = ''
   SET @c_LabelNo        = ''
   SET @c_Storerkey      = ''
   SET @c_Style          = ''
   SET @c_Color          = ''
   SET @c_Busr3          = ''
   SET @c_Busr4          = ''
   SET @c_Size           = ''
   SET @c_D_Userdefine03 = ''
   SET @c_D_Userdefine05 = ''
   SET @n_Qty            = 0
   --B2B END

   --B2C START
   DECLARE @n_MaxLine         INT = 13
   --B2C END

   --@c_Type
   --CASE WHEN 'M' THEN Call from Main Datawindow
   --     WHEN 'N' THEN B2B Datawindow
   --     WHEN 'E' THEN B2C Datawindow
   IF @c_Type = 'M'
   BEGIN
      SELECT DISTINCT
             OH.Orderkey
           , PH.Pickslipno
           , CASE WHEN ISNULL(OH.DocType,'') = 'E' THEN 'E' ELSE 'N' END AS DocType
      FROM ORDERS OH (NOLOCK)
      JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
      WHERE PH.PickSlipNo = @c_Pickslipno
   END

   IF @c_Type = 'N'
   BEGIN
      CREATE Table #TempPackListByCtn06 (
   	           OrderKey 		      NVARCHAR(30)  NULL 
               , ExternOrderkey 	   NVARCHAR(50)  NULL
               , ConsigneeKey       NVARCHAR(30)  NULL
               , ST_Company         NVARCHAR(45)  NULL  
               , OrdNotes           NVARCHAR(250) NULL
               , Susr5      		   NVARCHAR(20)  NULL
               , Susr4      		   NVARCHAR(20)  NULL
               , ST_Address 		   NVARCHAR(200) NULL
               , ST_Contact  		   NVARCHAR(90)  NULL
               , ST_State  		   NVARCHAR(45)  NULL
               , ST_City    		   NVARCHAR(45)  NULL
               , CartonNo 		      INT
               , PickSlipNo	      NVARCHAR(20)  NULL
               , PQty      	      INT 
               , BuyerPO            NVARCHAR(20)  NULL
               , SKUGroup  	      NVARCHAR(10)  NULL
               , ItemClass          NVARCHAR(10)  NULL
               , Price			      FLOAT
               , SKUSize            NVARCHAR(30)  NULL
      --       , NoOfCarton 	      INT NULL
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
      JOIN STORER ST WITH (NOLOCK) ON (ST.StorerKey = ORD.consigneekey)
      JOIN STORER ST1 WITH (NOLOCK) ON (ST1.StorerKey = ORD.storerkey)  
      JOIN PACKHEADER PH WITH (NOLOCK) ON (ORD.Orderkey = PH.Orderkey and ORD.Storerkey = PH.Storerkey)
      JOIN PACKDETAIL PDET WITH (NOLOCK) ON (PDET.PickSlipNo = PH.PickSlipNo)
      JOIN SKU S WITH  (NOLOCK) ON (PDET.Storerkey = S.Storerkey) AND (PDET.Sku = S.Sku)
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.long = ORD.[Stop]) AND (CL.listname = 'CBCODE')
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
                  , ST1.SUSR4
                  , CL.long

      SELECT *
      FROM #TempPackListByCtn06            
      ORDER BY ISNULL(CartonNo,0),ISNULL(skusize,'')
   END

   IF @c_Type = 'E'
   BEGIN
      CREATE TABLE #TMP_ECPL (
         C_Contact1        NVARCHAR(100)
       , Externorderkey    NVARCHAR(50)
       , AddDate           DATETIME
       , M_Company         NVARCHAR(100)
       , SKU               NVARCHAR(20)
       , ColorSize         NVARCHAR(50)
       , MANUFACTURERSKU   NVARCHAR(20)
       , UnitPrice         FLOAT
       , Qty               INT
       , C_Phone1          NVARCHAR(100)
       , C_Addresses       NVARCHAR(500)
       , Orderkey          NVARCHAR(10)
       , Pickslipno        NVARCHAR(10)
       , RowNumber         INT
       , MaxLine           INT
       , PageNumber        INT)
      
      INSERT INTO #TMP_ECPL
      SELECT DISTINCT
             ISNULL(OH.C_Contact1,'') AS C_Contact1
           , OH.Externorderkey
           , OH.AddDate
           , OH.M_Company
           , OD.SKU
           , TRIM(ISNULL(S.Color,'')) + '/' + TRIM(ISNULL(S.Size,'')) AS ColorSize
           , ISNULL(S.MANUFACTURERSKU,'') AS MANUFACTURERSKU
           , OD.UnitPrice
           , PD.Qty
           , ISNULL(OH.C_Phone1,'') AS C_Phone1
           , TRIM(ISNULL(OH.C_Address1,'')) + TRIM(ISNULL(OH.C_Address2,'')) + 
             TRIM(ISNULL(OH.C_Address3,'')) + TRIM(ISNULL(OH.C_Address4,'')) AS C_Addresses
           , OH.OrderKey
           , PH.Pickslipno
           , (Row_Number() OVER (PARTITION BY PH.Pickslipno ORDER BY PH.Pickslipno) - 1 ) + 1 AS RowNumber
           , @n_MaxLine AS MaxLine
           , (Row_Number() OVER (PARTITION BY PH.Pickslipno ORDER BY PH.Pickslipno) - 1 ) / @n_MaxLine + 1 AS PageNumber
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
      JOIN SKU S (NOLOCK) ON OD.Storerkey = S.Storerkey AND OD.SKU = S.SKU
      JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
      CROSS APPLY (SELECT SUM(PACKDETAIL.Qty) AS Qty
                   FROM PACKHEADER (NOLOCK)
                   JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo
                   WHERE PACKHEADER.PickSlipNo = PH.PickSlipNo) AS PD
      WHERE PH.PickSlipNo = @c_Pickslipno

      SELECT C_Contact1     
           , Externorderkey 
           , AddDate        
           , M_Company      
           , SKU            
           , ColorSize      
           , MANUFACTURERSKU
           , UnitPrice      
           , Qty            
           , C_Phone1       
           , C_Addresses    
           , Orderkey       
           , Pickslipno     
           , RowNumber      
           , MaxLine        
           , PageNumber     
      FROM #TMP_ECPL
      ORDER BY Pickslipno, SKU
   END

QUIT_SP:
   --B2B
   IF OBJECT_ID('tempdb..#TempPackListByCtn06') IS NOT NULL
      DROP TABLE #TempPackListByCtn06

   --B2C
   IF OBJECT_ID('tempdb..#TMP_ECPL') IS NOT NULL
      DROP TABLE #TMP_ECPL
END -- procedure

GO