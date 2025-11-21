SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Delivery_Note33_rpt                             */
/* Creation Date: 2018-10-04                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-5056 -[KR] Stussy Report Migration                       */
/*                                                                       */
/* Called By: r_dw_delivery_note33_rpt                                   */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/*************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note33_rpt] 
			(  @c_Orderkey    NVARCHAR(10)
			,  @c_Loadkey     NVARCHAR(10)= ''
			,  @c_Type        NVARCHAR(1) = ''
			)           
AS
BEGIN
	SET NOCOUNT ON
	SET ANSI_DEFAULTS OFF  
	SET QUOTED_IDENTIFIER OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @n_NoOfLine        INT
			, @n_TotDetail       INT
			, @n_LineNeed        INT
			, @n_SerialNo        INT
			, @b_debug           INT
			, @c_DelimiterSign   NVARCHAR(1)
			, @n_Count           int
			, @c_GetOrdkey       NVARCHAR(20)
			, @c_sku             NVARCHAR(20)
			, @c_ODUDF0102       NVARCHAR(120)
			, @n_seqno           INT
			, @c_ColValue        NVARCHAR(20)   
			, @c_SStyle          NVARCHAR(50)
			, @c_SColor          NVARCHAR(50)
			, @c_SSize           NVARCHAR(50)
			, @n_maxLine         INT
	
	SET @n_NoOfLine = 10
	SET @n_TotDetail= 0
	SET @n_LineNeed = 0
	SET @n_SerialNo = 0
	SET @b_debug    = 0


		CREATE TABLE #TMP_ORD33
				(  SeqNo          INT IDENTITY (1,1)
				,  Orderkey       NVARCHAR(10) DEFAULT ('')
				,  SKU            NVARCHAR(20) DEFAULT ('')
				,  TotalQty       INT         DEFAULT (0)
				,  RecGrp         INT         DEFAULT(0)
			 
				)

		CREATE TABLE #TMP_HDR33
				(  SeqNo         INT            
				,  Orderkey      NVARCHAR(10) NULL
				,  Storerkey     NVARCHAR(15) NULL
				,  C_Cphone1     NVARCHAR(30) NULL
				,  b_phone1      NVARCHAR(30) NULL
				,  CAddress      NVARCHAR(180) NULL
				,  SDescr        NVARCHAR(120) NULL
				,  SKU           NVARCHAR(120) NULL
				,  C_Zip         NVARCHAR(120) NULL
				,  OrderDate     DATETIME NULL
				,  Qty           INT  NULL
				,  RecGrp        INT NULL              
				,  SBUSR2        NVARCHAR(50) NULL
				,  C_Contact1    NVARCHAR(45) NULL
				,  B_Contact1    NVARCHAR(45) NULL
				,  MAddress      NVARCHAR(120) NULL
				,  B_Zip         NVARCHAR(120) NULL
				,  c_Country     NVARCHAR(45) NULL
				,  b_Country     NVARCHAR(45) NULL
				,  CNotes        NVARCHAR(120) NULL
				,  BuyerPO       NVARCHAR(20) NULL
			)

		IF ISNULL(RTRIM(@c_Orderkey),'') = ''
		BEGIN
		  
		  INSERT INTO #TMP_ORD33
				(  Orderkey
				,  SKU
				,  TotalQty
				,  RecGrp
				)
			SELECT DISTINCT OH.Orderkey
					,OD.sku
					,Sum(OD.originalqty)
				  ,(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,OD.sku Asc)-1)/@n_NoOfLine + 1 AS recgrp
			FROM Orders OH  WITH (NOLOCK) 
			JOIN OrderDetail OD (NOLOCK) ON OD.StorerKey = OH.StorerKey
												  AND OD.Orderkey  = OH.OrderKey
			WHERE OH.Loadkey = @c_Loadkey
			GROUP BY OH.Orderkey ,OD.sku
		 ORDER BY   OH.Orderkey ,OD.sku

		END 
		ELSE
		BEGIN
			 INSERT INTO #TMP_ORD33
				(  Orderkey
				,  SKU
				,  TotalQty
				,  RecGrp
				)
			SELECT DISTINCT OH.Orderkey
					,OD.sku
					,Sum(OD.originalqty)
				  ,(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,OD.sku Asc)-1)/@n_NoOfLine + 1 AS recgrp
			FROM Orders OH  WITH (NOLOCK) 
			JOIN OrderDetail OD (NOLOCK) ON OD.StorerKey = OH.StorerKey
												  AND OD.Orderkey  = OH.OrderKey
			WHERE OH.orderkey = @c_orderkey
			GROUP BY OH.Orderkey ,OD.sku
		 ORDER BY   OH.Orderkey ,OD.sku
		END

		INSERT INTO #TMP_HDR33
				(  SeqNo      
				,  Orderkey   
				,  Storerkey 
				,  C_Cphone1 
				,  b_phone1   
				,  CAddress     
				,  SDescr     
				,  SKU        
				,  C_Zip        
				,  OrderDate  
				,  Qty        
				,  RecGrp                  
				,  SBUSR2     
				,  C_Contact1  
				,  B_Contact1  
				,  MAddress  
				,  B_Zip       
				,  c_Country 
				,  b_Country 
				,  CNotes   
				,  BuyerPO  
			)
		SELECT DISTINCT 
				 TMP.SeqNo
				,OH.orderkey
				,OH.Storerkey
				,C_CPhone1  = 'T:' + OH.C_Phone1
				,b_phone1   = 'T:' + OH.b_phone1
				,Caddress   = (ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'')  )
				,SDESCR     = S.descr
				,SKU        = S.style + '-' + S.color + '-' + S.size --TMP.SKU
				,C_Zip      = (ISNULL(oh.c_city,'') + ISNULL(oh.c_State,'') +ISNULL(oh.c_Zip,'') ) 
				,OrderDate  = ISNULL(RTRIM(OH.OrderDate),'')
				,Qty        = TMP.TotalQty
				,RecGrp     = TMP.Recgrp
				,SBUSR2     = ISNULL(S.BUSR2,'') 
				,C_Contact1 = ISNULL(oh.c_contact1,'')
				,B_Contact1 = ISNULL(OH.b_contact1,'')
				,Maddress   = (ISNULL(OH.m_Address1,'') + ISNULL(OH.m_Address2,'')  )
				,B_Zip      = (ISNULL(OH.B_City,'') + ISNULL(OH.B_State,'') +ISNULL(OH.B_Zip,'') ) 
				,c_Country  = OH.c_Country
				,b_Country  = OH.b_Country
				,CNotes     = ISNULL(MAX(CASE WHEN CL.Code ='1' THEN RTRIM(CL.notes) ELSE '' END),'') 
				, BuyerPO   = ISNULL(OH.BuyerPO,'')
		FROM #TMP_ORD33 TMP
		JOIN ORDERS      OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)
		JOIN STORER      ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
		JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey) 
													 and OD.sku = TMP.sku
		JOIN SKU S WITH (NOLOCK) ON OD.storerkey = S.storerkey AND OD.sku = S.sku
		LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.listname = 'ssinv' And CL.storerkey = OH.Storerkey and CL.code='1'
		GROUP BY   TMP.SeqNo
					  ,OH.orderkey
					  ,OH.Storerkey
					  ,OH.C_Phone1
					  ,OH.b_phone1
					  ,(ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'')  )
					  ,S.descr
					  ,S.style , S.color, S.size--TMP.SKU
					  ,(ISNULL(c_city,'') + ISNULL(c_State,'') +ISNULL(c_Zip,'') ) 
					  ,ISNULL(RTRIM(OH.OrderDate),'')
					  ,TMP.TotalQty
					  ,TMP.Recgrp
					  ,ISNULL(S.BUSR2,'') 
					  ,ISNULL(c_contact1,'')
					  ,ISNULL(OH.b_contact1,'')
					  ,(ISNULL(OH.m_Address1,'') + ISNULL(OH.m_Address2,'')  )
					  ,(ISNULL(OH.B_City,'') + ISNULL(OH.B_State,'') +ISNULL(OH.B_Zip,'') ) 
					  ,OH.c_Country
					  ,OH.b_Country
					  ,ISNULL(OH.BuyerPO,'')
					  --,ISNULL(MAX(CASE WHEN CL.Code ='C10' THEN RTRIM(CL.long) ELSE '' END),'') 
		ORDER BY TMP.SeqNo

		
	 
		SELECT     SeqNo      
				,  Orderkey   
				,  Storerkey 
				,  C_Cphone1 
				,  b_phone1   
				,  CAddress     
				,  SDescr     
				,  SKU        
				,  C_Zip        
				,  OrderDate  
				,  Qty        
				,  RecGrp                  
				,  SBUSR2     
				,  C_Contact1  
				,  B_Contact1  
				,  MAddress  
				,  B_Zip       
				,  c_Country 
				,  b_Country 
				,  CNotes     
				, BuyerPO
		FROM #TMP_HDR33
		ORDER BY SeqNo                    

		
		DROP TABLE #TMP_HDR33
		GOTO QUIT_SP


QUIT_SP:  
END       

GO