SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store Procedure: isp_PackListBySku04                                       */  
/* Creation Date:                                                             */  
/* Copyright: IDS                                                             */  
/* Written by: YTWan                                                          */  
/*                                                                            */  
/* Purpose: SOS#242686- Generate QS PickPack List                             */  
/*        : Copy & Modify from nsp_PackListBySku03                            */  
/* Called By:                                                                 */  
/*                                                                            */  
/* PVCS Version: 1.3                                                          */  
/*                                                                            */  
/* Version: 5.4                                                               */  
/*                                                                            */  
/* Data Modifications:                                                        */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author    Ver.  Purposes                                      */
/* 27-May-2013  NJOW01    1.0   278733-Add sku.color                          */
/* 27-Nov-2013	NJOW02    1.1   295959-Map carrier(consigneekey) to           */
/*                              orders.deliveryplace                          */
/* 25-JAN-2017  JayLim   1.2  SQL2012 compatibility modification (Jay01)*/  
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/******************************************************************************/  
  
CREATE PROC [dbo].[isp_PackListBySku04] (
         @c_PickSlipNo NVARCHAR(10))  
AS   
   SET ANSI_WARNINGS OFF
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
      	, @c_Storerkey 	 NVARCHAR(15)          	
      	, @c_Style 			 NVARCHAR(20)
      	, @c_Color       NVARCHAR(10)
      	, @c_Busr3			   NVARCHAR(30) 
      	, @c_Busr4 			 NVARCHAR(30) 
      	, @c_Size 			 NVARCHAR(5) 
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

   CREATE Table #TempNPPL (
                 ST_Company         NVARCHAR(45) 
               , Logo1              NVARCHAR(60) 
               , Logo2              NVARCHAR(60)
               , Logo3              NVARCHAR(60)
               , OrderKey 		      NVARCHAR(30) 
               , ExternOrderkey 	   NVARCHAR(50)   --tlting_ext
               , ConsigneeKey       NVARCHAR(30)
               , BuyerPO            NVARCHAR(20)  
               , M_Company 		   NVARCHAR(45) 
               , M_Address1 		   NVARCHAR(45) 
               , M_Address2 		   NVARCHAR(45) 
               , M_Address3 		   NVARCHAR(45) 
               , M_Address4 		   NVARCHAR(45) 
               , M_City 			   NVARCHAR(45) 
               , M_State 			   NVARCHAR(45) 
               , M_Zip 			      NVARCHAR(18) 
               , M_Country 		   NVARCHAR(45) 
               , M_Contact1 		   NVARCHAR(30)
               , M_Phone1 		      NVARCHAR(20) 
               , B_Company 		   NVARCHAR(45) 
               , B_Address1 		   NVARCHAR(45) 
               , B_Address2 		   NVARCHAR(45) 
               , B_Address3 		   NVARCHAR(45) 
               , B_Address4 		   NVARCHAR(45) 
               , B_City 			   NVARCHAR(45) 
               , B_State 			   NVARCHAR(45) 
               , B_Zip 			      NVARCHAR(18) 
               , B_Country 		   NVARCHAR(45)
               , Salesman 		      NVARCHAR(30)
               , Userdefine03       NVARCHAR(20)
               , PickSlipNo	      NVARCHAR(20) 
               , CartonNo 		      INT
               , LabelNo    	      NVARCHAR(20) 
               , Storerkey 	      NVARCHAR(15) 
               , Style 			      NVARCHAR(20) 
               , Color            NVARCHAR(10)
               , Busr3			      NVARCHAR(30) 
               , Busr4			      NVARCHAR(30) 
               , Weight			      FLOAT
               , [Cube]               FLOAT
               , DET_Userdefine03   NVARCHAR(18)
               , DET_Userdefine05   NVARCHAR(18)
               , SizeCOL1 		      NVARCHAR(5)  NULL	, QtyCOL1 	INT	NULL	
               , SizeCOL2 		      NVARCHAR(5)  NULL  , QtyCOL2 	INT	NULL  
               , SizeCOL3 		      NVARCHAR(5)  NULL  , QtyCOL3 	INT	NULL  
               , SizeCOL4 		      NVARCHAR(5)  NULL  , QtyCOL4 	INT	NULL  
               , SizeCOL5 		      NVARCHAR(5)  NULL  , QtyCOL5 	INT	NULL  
               , SizeCOL6 		      NVARCHAR(5)  NULL  , QtyCOL6 	INT	NULL  
               , SizeCOL7 		      NVARCHAR(5)  NULL  , QtyCOL7 	INT	NULL  
               , SizeCOL8 		      NVARCHAR(5)  NULL  , QtyCOL8 	INT	NULL  
               , SizeCOL9 		      NVARCHAR(5)  NULL  , QtyCOL9 	INT	NULL  
               , SizeCOL10 	      NVARCHAR(5) 	NULL	, QtyCOL10 	INT	NULL  
               , SizeCOL11 	      NVARCHAR(5) 	NULL	, QtyCOL11 	INT	NULL  
               , SizeCOL12 	      NVARCHAR(5) 	NULL	, QtyCOL12 	INT	NULL  
               , SizeCOL13 	      NVARCHAR(5) 	NULL	, QtyCOL13 	INT	NULL  
               , SizeCOL14 	      NVARCHAR(5) 	NULL	, QtyCOL14 	INT	NULL  
               , SizeCOL15 	      NVARCHAR(5) 	NULL	, QtyCOL15 	INT	NULL  
               , SizeCOL16 	      NVARCHAR(5) 	NULL	, QtyCOL16 	INT	NULL  
               , SizeCOL17 	      NVARCHAR(5) 	NULL	, QtyCOL17 	INT	NULL  
               , SizeCOL18 	      NVARCHAR(5) 	NULL	, QtyCOL18 	INT	NULL  
               , SizeCOL19 	      NVARCHAR(5) 	NULL	, QtyCOL19 	INT	NULL  
               , SizeCOL20 	      NVARCHAR(5) 	NULL	, QtyCOL20 	INT	NULL  
               , SizeCOL21 	      NVARCHAR(5) 	NULL	, QtyCOL21 	INT	NULL  
               , SizeCOL22 	      NVARCHAR(5) 	NULL	, QtyCOL22 	INT	NULL  
               , SizeCOL23 	      NVARCHAR(5) 	NULL	, QtyCOL23 	INT	NULL  
               , SizeCOL24 	      NVARCHAR(5) 	NULL	, QtyCOL24 	INT	NULL  
               , SizeCOL25 	      NVARCHAR(5) 	NULL	, QtyCOL25 	INT	NULL  
               , SizeCOL26 	      NVARCHAR(5) 	NULL	, QtyCOL26 	INT	NULL  
               , SizeCOL27 	      NVARCHAR(5) 	NULL	, QtyCOL27 	INT	NULL  
               , SizeCOL28 	      NVARCHAR(5) 	NULL	, QtyCOL28 	INT	NULL  
               , SizeCOL29 	      NVARCHAR(5) 	NULL	, QtyCOL29 	INT	NULL  
               , SizeCOL30 	      NVARCHAR(5) 	NULL	, QtyCOL30 	INT 	NULL  
               , NoOfCarton 	      INT NULL
    ) 

   SELECT @n_NoOfCarton = COUNT(DISTINCT CartonNo) 
         ,@c_Storerkey  = ISNULL(RTRIM(Storerkey),'')         
   FROM  PACKDETAIL WITH (NOLOCK) 
   WHERE pickslipno = @c_PickSlipNo 
   GROUP BY ISNULL(RTRIM(Storerkey),'')

   SELECT @c_Logo1 = ISNULL(CONVERT(NVARCHAR(60),Notes),'')
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'RPTLOGO'
   AND   CODE = @c_Storerkey + 'bmp1'
   AND   Storerkey = @c_Storerkey
   AND   Long = 'r_dw_packing_list_by_sku04'

   SELECT @c_Logo2 = ISNULL(CONVERT(NVARCHAR(60),Notes),'')
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'RPTLOGO'
   AND   CODE = @c_Storerkey + 'bmp2'
   AND   Storerkey = @c_Storerkey
   AND   Long = 'r_dw_packing_list_by_sku04'

   SELECT @c_Logo3 = ISNULL(CONVERT(NVARCHAR(60),Notes),'')

   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'RPTLOGO'
   AND   CODE = @c_Storerkey + 'bmp3'
   AND   Storerkey = @c_Storerkey
   AND   Long = 'r_dw_packing_list_by_sku04'


   INSERT INTO #TempNPPL (
                       ST_Company
                     , Logo1
                     , Logo2
                     , Logo3
                     , OrderKey
                     , ExternOrderKey
                     , Consigneekey
                     , BuyerPO
                     , M_Company
                     , M_address1
                     , M_address2
                     , M_address3
                     , M_address4
                     , M_City
                     , M_State
                     , M_Zip 			      
                     , M_Country
                     , M_Contact1
                     , M_Phone1
                     , B_Company
                     , B_address1
                     , B_address2
                     , B_address3
                     , B_address4
                     , B_City
                     , B_State
                     , B_Zip 
                     , B_Country
                     , SalesMan 
                     , Userdefine03
                     , PickSlipNo 
                     , CartonNo
                     , LabelNo
                     , Storerkey
                     , Style 		
                     , Color 
                     , Busr3		 
                     , Busr4
                     , Weight
                     , [Cube]
                     , DET_Userdefine03
                     , DET_Userdefine05
                     , NoOfCarton)
   SELECT DISTINCT
          ISNULL(RTRIM(ST.Company),'')                            AS ST_Company
        , @c_Logo1                                                AS Logo1
        , @c_Logo2                                                AS Logo2
        , @c_Logo3                                                AS Logo3
        , ISNULL(RTRIM(O.Orderkey),'')                            AS OrderKey
        , ISNULL(RTRIM(O.ExternOrderKey),'')                      AS ExternOrderKey
        --, ISNULL(RTRIM(SUBSTRING(O.ConsigneeKey,3,13)),'')        AS ConsigneeKey
        , ISNULL(RTRIM(O.DeliveryPlace),'')                          AS ConsigneeKey --NJOW02
        , ISNULL(RTRIM(O.BuyerPO),'')                             AS BuyerPO 
        , ISNULL(RTRIM(O.M_Company),'')									AS M_Company 
        , ISNULL(RTRIM(O.M_address1),'')								   AS M_address1
        , ISNULL(RTRIM(O.M_address2),'')                          AS M_address2
        , ISNULL(RTRIM(O.M_address3),'')                          AS M_address3
        , ISNULL(RTRIM(O.M_address4),'')                          AS M_address4
        , ISNULL(RTRIM(O.M_City),'')                              AS M_City    
        , ISNULL(RTRIM(O.M_State),'')                             AS M_State  
        , ISNULL(RTRIM(O.M_Zip),'')                               AS M_Zip
        , ISNULL(RTRIM(O.M_Country),'')                           AS M_Country 
        , ISNULL(RTRIM(O.M_Contact1),'')                          AS M_Contact1
        , ISNULL(RTRIM(O.M_Phone1),'')                            AS M_Phone1  
        , ISNULL(RTRIM(O.B_Company),'')                           AS B_Company 
        , ISNULL(RTRIM(O.B_address1),'')                          AS B_address1
        , ISNULL(RTRIM(O.B_address2),'')                          AS B_address2
        , ISNULL(RTRIM(O.B_address3),'')                          AS B_address3
        , ISNULL(RTRIM(O.B_address4),'')                          AS B_address4
        , ISNULL(RTRIM(O.B_City),'')                              AS B_City    
        , ISNULL(RTRIM(O.B_State),'')                             AS B_State  
        , ISNULL(RTRIM(O.B_Zip),'')                               AS B_Zip 
        , ISNULL(RTRIM(O.B_Country),'')                           AS B_Country 
        , ISNULL(RTRIM(O.SalesMan),'')                            AS SalesMan   
        , ISNULL(RTRIM(O.UserDefine03),'')                        AS UserDefine03 
        , ISNULL(RTRIM(PH.PickSlipNo),'')                         AS PickSlipNo
        , ISNULL(PD.CartonNo,0)                                   AS CartonNo
        , ISNULL(RTRIM(PD.LabelNo),'')                            AS LabelNo
        , ISNULL(RTRIM(PD.Storerkey),'')                          AS Storerkey  
        , ISNULL(RTRIM(S.Style),'')                               AS Style
        , ISNULL(RTRIM(S.Color),'')                               AS Color
        , ISNULL(RTRIM(S.Busr3),'')                               AS Busr3
        , ISNULL(RTRIM(S.Busr4),'')                               AS Busr4
        , SUM(ISNULL(S.StdGrossWgt,0.00000) * ISNULL(PCK.Qty,0))  AS Weight
        , ISNULL(PI.[Cube],0.00000)                                 AS Cube
        , ISNULL(RTRIM(OD.UserDefine03),'')                       AS DET_UserDefine03
        , ISNULL(RTRIM(OD.UserDefine05),'')                       AS DET_UserDefine05
        , @n_NoOfCarton                                           AS NoOfCarton
   FROM ORDERS O  WITH (NOLOCK)
   JOIN STORER ST WITH (NOLOCK)
     ON (ST.StorerKey = O.Storerkey)
   JOIN PACKHEADER PH WITH (NOLOCK) 
     ON (O.Orderkey = PH.Orderkey and O.Storerkey = PH.Storerkey)
   JOIN PACKDETAIL PD WITH (NOLOCK) 
     ON (PD.PickSlipNo = PH.PickSlipNo)
   JOIN SKU S WITH  (NOLOCK) 
     ON (PD.Storerkey = S.Storerkey)
    AND (PD.Sku = S.Sku)
   JOIN PICKDETAIL PCK WITH (NOLOCK)
     ON (O.Orderkey = PCK.Orderkey)
    AND (PD.Storerkey = PCK.Storerkey)
    AND (PD.Sku = PCK.Sku)
    AND (RIGHT(PD.LabelNo,18) = PCK.DropID)
   JOIN ORDERDETAIL OD WITH (NOLOCK)
     ON (OD.Orderkey = PCK.Orderkey)
    AND (OD.OrderLineNumber = PCK.OrderLineNumber)
   LEFT JOIN PACKINFO PI WITH (NOLOCK) 
     ON (PD.PickSlipNo = PI.PickSlipNo)
     AND(PD.CartonNo = PI.CartonNo)
   WHERE PH.PickSlipNo = @c_PickSlipNo 
   GROUP BY
        ISNULL(RTRIM(ST.Company),'')                             
      , ISNULL(RTRIM(O.Orderkey),'')                             
      , ISNULL(RTRIM(O.ExternOrderKey),'')                      
      --, ISNULL(RTRIM(SUBSTRING(O.ConsigneeKey,3,13)),'')                         
      , ISNULL(RTRIM(O.DeliveryPlace),'')  --NJOW02                      
      , ISNULL(RTRIM(O.BuyerPO),'')                              
      , ISNULL(RTRIM(O.M_Company),'')									 
      , ISNULL(RTRIM(O.M_address1),'')								   
      , ISNULL(RTRIM(O.M_address2),'')                           
      , ISNULL(RTRIM(O.M_address3),'')                           
      , ISNULL(RTRIM(O.M_address4),'')                           
      , ISNULL(RTRIM(O.M_City),'')                                
      , ISNULL(RTRIM(O.M_State),'')                             
      , ISNULL(RTRIM(O.M_Zip),'')  
      , ISNULL(RTRIM(O.M_Country),'')                           
      , ISNULL(RTRIM(O.M_Contact1),'')                           
      , ISNULL(RTRIM(O.M_Phone1),'')                            
      , ISNULL(RTRIM(O.B_Company),'')                           
      , ISNULL(RTRIM(O.B_address1),'')                           
      , ISNULL(RTRIM(O.B_address2),'')                           
      , ISNULL(RTRIM(O.B_address3),'')                           
      , ISNULL(RTRIM(O.B_address4),'')                           
      , ISNULL(RTRIM(O.B_City),'')                                  
      , ISNULL(RTRIM(O.B_State),'')  
      , ISNULL(RTRIM(O.B_Zip),'')                             
      , ISNULL(RTRIM(O.B_Country),'')
      , ISNULL(RTRIM(O.SalesMan),'')                              
      , ISNULL(RTRIM(O.UserDefine03),'')                                                    
      , ISNULL(RTRIM(PH.PickSlipNo),'')                          
      , ISNULL(PD.CartonNo,0)   
      , ISNULL(RTRIM(PD.LabelNo),'')                                 
      , ISNULL(RTRIM(PD.Storerkey),'')                           
      , ISNULL(RTRIM(S.Style),'')                                
      , ISNULL(RTRIM(S.Color),'') 
      , ISNULL(RTRIM(S.Busr3),'')                                
      , ISNULL(RTRIM(S.Busr4),'')                                
      , ISNULL(PI.[Cube],0.00000)   
      , ISNULL(RTRIM(OD.UserDefine03),'')                       
      , ISNULL(RTRIM(OD.UserDefine05),'')                              


   DECLARE PACK_CUR CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT CartonNo
        , LabelNo
        , Orderkey
        , Storerkey
        , Style
        , Color
        , Busr3
        , Busr4
        , DET_Userdefine03
        , DET_Userdefine05
   FROM #TempNPPL
   ORDER BY CartonNo
          , Style          
          , Busr3
          , Busr4
          , Color
          , DET_Userdefine03
          , DET_Userdefine05
   OPEN PACK_CUR  
  
   FETCH NEXT FROM PACK_CUR INTO @n_CartonNo
                              ,  @c_LabelNo
                              ,  @c_Orderkey
                              ,  @c_Storerkey
                              ,  @c_Style
                              ,  @c_Color
                              ,  @c_Busr3
                              ,  @c_Busr4
                              ,  @c_D_Userdefine03
                              ,  @c_D_Userdefine05
 
   WHILE @@FETCH_STATUS = 0  
   BEGIN 
      SET @n_Cnt = 1 
      DECLARE SIZE_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT ISNULL(RTRIM(S.Size),'')
         ,   ISNULL(SUM(PD.Qty),0)
      FROM PICKDETAIL  PD WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey) AND (PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN SKU S WITH (NOLOCK) ON (OD.Storerkey = S.Storerkey AND OD.SKU = S.SKU)
      WHERE PD.Orderkey = @c_Orderkey
      AND PD.DropID = RIGHT(@c_LabelNo,18)  
      AND ISNULL(RTRIM(OD.UserDefine03),'') = @c_D_Userdefine03
      AND ISNULL(RTRIM(OD.UserDefine05),'') = @c_D_Userdefine05
      AND ISNULL(RTRIM(S.Style),'') = @c_Style
      AND ISNULL(RTRIM(S.Color),'') = @c_Color
      AND ISNULL(RTRIM(S.Busr3),'') = @c_Busr3
      AND ISNULL(RTRIM(S.Busr4),'') = @c_Busr4
      GROUP BY ISNULL(RTRIM(S.Size),'')
            ,  ISNULL(RTRIM(S.Measurement),'') 
      ORDER BY ISNULL(RTRIM(S.Measurement),'')  

      OPEN SIZE_CUR 

      FETCH NEXT FROM SIZE_CUR INTO @c_Size, @n_Qty 

      WHILE @@FETCH_STATUS = 0   
      BEGIN  
         SET @c_ExecSQLStmt = N'UPDATE #TempNPPL SET SizeCOL'+RTRIM(CONVERT(NVARCHAR(2),@n_Cnt))+'=N'''+RTRIM(@c_Size) + '''' 
                            + ',QtyCOL'+RTRIM(CONVERT(NVARCHAR(2),@n_Cnt))+'=@n_qty'  
                            + ' WHERE PickSlipNo = @c_PickSlipNo' 
                            + ' AND LabelNo = @c_LabelNo'  
                            + ' AND Style = @c_Style'
                            + ' AND Busr3 = @c_Busr3'
                            + ' AND Color = @c_Color'
                            + ' AND Busr4 = @c_Busr4'
                            + ' AND DET_Userdefine03 = @c_D_Userdefine03'
                            + ' AND DET_Userdefine05 = @c_D_Userdefine05'

         SET @c_ExecArguments = N'@c_PickSlipNo       NVARCHAR(10)'            
                              + ',@c_LabelNo          NVARCHAR(20)' 
                              + ',@c_Style            NVARCHAR(20)' 
                              + ',@c_Busr3            NVARCHAR(30)'  
                              + ',@c_Color            NVARCHAR(10)' 
                              + ',@c_Busr4            NVARCHAR(30)' 
                              + ',@c_D_Userdefine03   NVARCHAR(18)'
                              + ',@c_D_Userdefine05   NVARCHAR(18)'    
                              + ',@n_Qty              INT'            

         EXEC sp_ExecuteSql @c_ExecSQLStmt             
                          , @c_ExecArguments             
                          , @c_PickSlipNo             
                          , @c_LabelNo 
                          , @c_Style                                       
                          , @c_Busr3
                          , @c_Color
                          , @c_Busr4 
                          , @c_D_Userdefine03
                          , @c_D_Userdefine05
                          , @n_Qty   
 
         SET @n_Cnt = @n_Cnt + 1  

         FETCH NEXT FROM SIZE_CUR INTO @c_Size, @n_Qty                                                                          
      END -- SIZE_CUR WHILE loop   
 
      CLOSE SIZE_CUR  
      DEALLOCATE SIZE_CUR  
  
      FETCH NEXT FROM PACK_CUR INTO @n_CartonNo
                                 ,  @c_LabelNo
                                 ,  @c_Orderkey
                                 ,  @c_Storerkey
                                 ,  @c_Style
                                 ,  @c_Color
                                 ,  @c_Busr3
                                 ,  @c_Busr4
                                 ,  @c_D_Userdefine03
                                 ,  @c_D_Userdefine05
   END -- PACK_CUR WHILE loop  
  
   CLOSE PACK_CUR  
   DEALLOCATE PACK_CUR  

   SELECT ST_Company = ISNULL(RTRIM(ST_Company),'')  
         ,Logo1      = ISNULL(RTRIM(Logo1),'')
         ,Logo2      = ISNULL(RTRIM(Logo2),'')
         ,Logo3      = ISNULL(RTRIM(Logo3),'')
         ,OrderKey   = ISNULL(RTRIM(OrderKey),'')            
			,ExternOrderKey= ISNULL(RTRIM(ExternOrderKey),'')
			,ConsigneeKey  = ISNULL(RTRIM(ConsigneeKey),'')      
         ,BuyerPO       = ISNULL(RTRIM(BuyerPO),'') 
         ,m_company     = ISNULL(RTRIM(m_company),'')            
         ,m_address1    = ISNULL(RTRIM(m_address1),'')           
         ,m_address2    = ISNULL(RTRIM(m_address2),'')           
         ,m_address3    = ISNULL(RTRIM(m_address3),'')           
         ,m_address4    = ISNULL(RTRIM(m_address4),'')           
         ,m_City        = ISNULL(RTRIM(m_City),'')               
         ,m_State       = ISNULL(RTRIM(m_State),'')    
         ,m_Zip         = ISNULL(RTRIM(m_Zip),'')             
         ,m_Country     = ISNULL(RTRIM(m_Country),'')            
         ,m_Contact1    = ISNULL(RTRIM(m_Contact1),'')           
         ,m_phone1      = ISNULL(RTRIM(m_phone1),'')  
         ,b_company     = ISNULL(RTRIM(b_company),'')            
         ,b_address1    = ISNULL(RTRIM(b_address1),'')           
         ,b_address2    = ISNULL(RTRIM(b_address2),'')           
         ,b_address3    = ISNULL(RTRIM(b_address3),'')           
         ,b_address4    = ISNULL(RTRIM(b_address4),'')           
         ,b_City        = ISNULL(RTRIM(b_City),'')               
         ,b_State       = ISNULL(RTRIM(b_State),'')  
         ,b_Zip         = ISNULL(RTRIM(b_Zip),'')               
         ,b_Country     = ISNULL(RTRIM(b_Country),'')  
         ,SalesMan      = ISNULL(RTRIM(SalesMan),'')
         ,UserDefine03  = ISNULL(RTRIM(UserDefine03),'')
         ,PickSlipNo    = ISNULL(RTRIM(PickSlipNo),'')              
         ,CartonNo      = ISNULL(CartonNo,0) 
         ,Storerkey     = ISNULL(RTRIM(Storerkey),'')   
         ,Style         = ISNULL(RTRIM(Style),'')  
         ,Color         = ISNULL(RTRIM(Color),'') 
         ,Busr3         = ISNULL(RTRIM(Busr3),'')           
         ,Busr4         = ISNULL(RTRIM(Busr4),'')  
         ,Weight        = ISNULL(Weight,0.00000) 
         ,[Cube]          = ISNULL([Cube],0.00000) 
         ,DET_UserDefine03= ISNULL(RTRIM(DET_UserDefine03),'')  
         ,DET_UserDefine05= ISNULL(RTRIM(DET_UserDefine05),'')            
	      ,SizeCOL1      = ISNULL(RTRIM(SizeCOL1),'') , QtyCOL1    = ISNULL(QtyCOL1 ,0)
         ,SizeCOL2      = ISNULL(RTRIM(SizeCOL2),'') , QtyCOL2    = ISNULL(QtyCOL2 ,0)
         ,SizeCOL3      = ISNULL(RTRIM(SizeCOL3),'') , QtyCOL3    = ISNULL(QtyCOL3 ,0)
         ,SizeCOL4      = ISNULL(RTRIM(SizeCOL4),'') , QtyCOL4    = ISNULL(QtyCOL4 ,0)
         ,SizeCOL5      = ISNULL(RTRIM(SizeCOL5),'') , QtyCOL5    = ISNULL(QtyCOL5 ,0)
         ,SizeCOL6      = ISNULL(RTRIM(SizeCOL6),'') , QtyCOL6    = ISNULL(QtyCOL6 ,0)
         ,SizeCOL7      = ISNULL(RTRIM(SizeCOL7),'') , QtyCOL7    = ISNULL(QtyCOL7 ,0)
         ,SizeCOL8      = ISNULL(RTRIM(SizeCOL8),'') , QtyCOL8    = ISNULL(QtyCOL8 ,0)
         ,SizeCOL9      = ISNULL(RTRIM(SizeCOL9),'') , QtyCOL9    = ISNULL(QtyCOL9 ,0)
         ,SizeCOL10     = ISNULL(RTRIM(SizeCOL10),''), QtyCOL10   = ISNULL(QtyCOL10,0)
         ,SizeCOL11     = ISNULL(RTRIM(SizeCOL11),''), QtyCOL11   = ISNULL(QtyCOL11,0)
         ,SizeCOL12     = ISNULL(RTRIM(SizeCOL12),''), QtyCOL12   = ISNULL(QtyCOL12,0)
         ,SizeCOL13     = ISNULL(RTRIM(SizeCOL13),''), QtyCOL13   = ISNULL(QtyCOL13,0)
         ,SizeCOL14     = ISNULL(RTRIM(SizeCOL14),''), QtyCOL14   = ISNULL(QtyCOL14,0)
         ,SizeCOL15     = ISNULL(RTRIM(SizeCOL15),''), QtyCOL15   = ISNULL(QtyCOL15,0)
         ,SizeCOL16     = ISNULL(RTRIM(SizeCOL16),''), QtyCOL16   = ISNULL(QtyCOL16,0)
         ,SizeCOL17     = ISNULL(RTRIM(SizeCOL17),''), QtyCOL17   = ISNULL(QtyCOL17,0)
         ,SizeCOL18     = ISNULL(RTRIM(SizeCOL18),''), QtyCOL18   = ISNULL(QtyCOL18,0)
         ,SizeCOL19     = ISNULL(RTRIM(SizeCOL19),''), QtyCOL19   = ISNULL(QtyCOL19,0)
         ,SizeCOL20     = ISNULL(RTRIM(SizeCOL20),''), QtyCOL20   = ISNULL(QtyCOL20,0)
         ,SizeCOL21     = ISNULL(RTRIM(SizeCOL21),''), QtyCOL21   = ISNULL(QtyCOL21,0)
         ,SizeCOL22     = ISNULL(RTRIM(SizeCOL22),''), QtyCOL22   = ISNULL(QtyCOL22,0)
         ,SizeCOL23     = ISNULL(RTRIM(SizeCOL23),''), QtyCOL23   = ISNULL(QtyCOL23,0)
         ,SizeCOL24     = ISNULL(RTRIM(SizeCOL24),''), QtyCOL24   = ISNULL(QtyCOL24,0)
         ,SizeCOL25     = ISNULL(RTRIM(SizeCOL25),''), QtyCOL25   = ISNULL(QtyCOL25,0)
         ,SizeCOL26     = ISNULL(RTRIM(SizeCOL26),''), QtyCOL26   = ISNULL(QtyCOL26,0)
         ,SizeCOL27     = ISNULL(RTRIM(SizeCOL27),''), QtyCOL27   = ISNULL(QtyCOL27,0)
         ,SizeCOL28     = ISNULL(RTRIM(SizeCOL28),''), QtyCOL28   = ISNULL(QtyCOL28,0)
         ,SizeCOL29     = ISNULL(RTRIM(SizeCOL29),''), QtyCOL29   = ISNULL(QtyCOL29,0)
         ,SizeCOL30     = ISNULL(RTRIM(SizeCOL30),''), QtyCOL30   = ISNULL(QtyCOL30,0)
         ,ISNULL(NoOfCarton,0) 
   FROM #TempNPPL            
   ORDER BY ISNULL(RTRIM(PickSlipNo),'')  
         ,  ISNULL(RTRIM(Storerkey),'')           
         ,  ISNULL(CartonNo,0)         
         ,  ISNULL(RTRIM(Style),'')   
         ,  ISNULL(RTRIM(Busr3),'')           
         ,  ISNULL(RTRIM(Busr4),'')              
         ,  ISNULL(RTRIM(Color),'')    

   DROP TABLE #TempNPPL
END  

GO