SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Delivery_Note32_RDT                             */
/* Creation Date: 2018-09-24                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-6168 - [JP] Herschel - Delivery Note                     */
/*                                                                       */
/* Called By: r_dw_delivery_note32_rdt                                   */
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

CREATE PROC [dbo].[isp_Delivery_Note32_RDT] 
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


      CREATE TABLE #TMP_ORD32
            (  SeqNo          INT IDENTITY (1,1)
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')
				,  SKU            NVARCHAR(20) DEFAULT ('')
            ,  TotalQty       INT         DEFAULT (0)
				,  RecGrp         INT         DEFAULT(0)
          
            )

      CREATE TABLE #TMP_HDR32
            (  SeqNo         INT            
            ,  Orderkey      NVARCHAR(10) NULL
            ,  Storerkey     NVARCHAR(15) NULL
            ,  C_Cphone1     NVARCHAR(30) NULL
            ,  C_Company     NVARCHAR(45) NULL
            ,  CAddress      NVARCHAR(180) NULL
            ,  SDescr        NVARCHAR(120) NULL
            ,  SKU           NVARCHAR(20) NULL
            ,  C_Zip         NVARCHAR(120) NULL
            ,  OrderDate     DATETIME NULL
            ,  Qty          INT  NULL
            ,  RecGrp        INT NULL              
				,  ExtOrdKey     NVARCHAR(20) NULL
				,  C01           NVARCHAR(120) NULL
				,  C02           NVARCHAR(120) NULL
				,  C03           NVARCHAR(120) NULL
				,  C04           NVARCHAR(120) NULL
				,  C05           NVARCHAR(120) NULL
				,  C06           NVARCHAR(120) NULL
				,  C07           NVARCHAR(120) NULL
				,  C08           NVARCHAR(120) NULL
				,  C09           NVARCHAR(120) NULL
				,  C10           NVARCHAR(120) NULL)

      IF ISNULL(RTRIM(@c_Orderkey),'') = ''
      BEGIN
		  
		  INSERT INTO #TMP_ORD32
            (  Orderkey
				,  SKU
            ,  TotalQty
				,  RecGrp
            )
         SELECT DISTINCT OH.Orderkey
			      ,OD.sku
               ,Sum( OD.ShippedQty + OD.QtyAllocated + OD.QtyPicked)
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
          INSERT INTO #TMP_ORD32
            (  Orderkey
				,  SKU
            ,  TotalQty
				,  RecGrp
            )
         SELECT DISTINCT OH.Orderkey
			      ,OD.sku
               ,Sum( OD.ShippedQty + OD.QtyAllocated + OD.QtyPicked)
				  ,(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,OD.sku Asc)-1)/@n_NoOfLine + 1 AS recgrp
         FROM Orders OH  WITH (NOLOCK) 
         JOIN OrderDetail OD (NOLOCK) ON OD.StorerKey = OH.StorerKey
                                      AND OD.Orderkey  = OH.OrderKey
         WHERE OH.orderkey = @c_orderkey
         GROUP BY OH.Orderkey ,OD.sku
       ORDER BY   OH.Orderkey ,OD.sku
      END

      INSERT INTO #TMP_HDR32
            (   SeqNo   
             ,  Orderkey     
             ,  Storerkey    
             ,  C_Cphone1   
             ,  C_Company       
             ,  CAddress       
             ,  Sdescr       
             ,  SKU          
             ,  C_Zip            
             ,  OrderDate     
             ,  Qty       
				 ,  RecGrp  
				 ,  ExtOrdkey   
				 ,  C01
				 ,  C02
				 ,  C03
				 ,  C04
				 ,  C05
				 ,  C06
				 ,  C07
				 ,  C08
				 ,  C09
				 ,  C10
             )
      SELECT DISTINCT 
             TMP.SeqNo
            ,OH.orderkey
            ,OH.Storerkey
				,C_CPhone1 = OH.C_Phone1
            ,C_Company = OH.c_company
            ,Caddress = (ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'') + ISNULL(OH.C_Address3,'') + ISNULL(OH.C_Address4,'') )
            ,SDESCR = S.descr
            ,SKU = TMP.SKU
            ,C_Zip  = (N'?'  + ISNULL(c_Zip,'') + ISNULL(c_State,'') +ISNULL(c_city,'') ) 
            ,OrderDate  = ISNULL(RTRIM(OH.OrderDate),'') 
            ,Qty    = TMP.TotalQty
				,RecGrp = TMP.Recgrp
				,ExtOrdkey  = OH.Externorderkey 
				,C01 = ISNULL(MAX(CASE WHEN CL.Code ='C01' THEN RTRIM(CL.long) ELSE '' END),'') 
				,C02 = ISNULL(MAX(CASE WHEN CL.Code ='C02' THEN RTRIM(CL.long) ELSE '' END),'') 
				,C03 = ISNULL(MAX(CASE WHEN CL.Code ='C03' THEN RTRIM(CL.long) ELSE '' END),'') 
				,C04 = ISNULL(MAX(CASE WHEN CL.Code ='C04' THEN RTRIM(CL.long) ELSE '' END),'') 
				,C05 = ISNULL(MAX(CASE WHEN CL.Code ='C05' THEN RTRIM(CL.long) ELSE '' END),'') 
				,C06 = ISNULL(MAX(CASE WHEN CL.Code ='C06' THEN RTRIM(CL.long) ELSE '' END),'') 
				,C07 = ISNULL(MAX(CASE WHEN CL.Code ='C07' THEN RTRIM(CL.long) ELSE '' END),'') 
				,C08 = ISNULL(MAX(CASE WHEN CL.Code ='C08' THEN RTRIM(CL.long) ELSE '' END),'') 
				,C09 = ISNULL(MAX(CASE WHEN CL.Code ='C09' THEN RTRIM(CL.long) ELSE '' END),'') 
				,C10 = ISNULL(MAX(CASE WHEN CL.Code ='C10' THEN RTRIM(CL.long) ELSE '' END),'') 
      FROM #TMP_ORD32 TMP
      JOIN ORDERS      OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)
      JOIN STORER      ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey) 
		                                  and OD.sku = TMP.sku
      JOIN SKU S WITH (NOLOCK) ON OD.storerkey = S.storerkey AND OD.sku = S.sku
		LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.listname = 'HSDN' And CL.storerkey = OH.Storerkey
      GROUP BY TMP.SeqNo
            ,OH.orderkey
            ,OH.Storerkey
				,OH.C_Phone1
            ,OH.c_company
            ,(ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'') + ISNULL(OH.C_Address3,'') + ISNULL(OH.C_Address4,'') )
            ,S.descr
            ,TMP.SKU
            ,(N'?'  + ISNULL(c_Zip,'') + ISNULL(c_State,'') +ISNULL(c_city,'') ) 
            ,ISNULL(RTRIM(OH.OrderDate),'') 
            ,TMP.TotalQty
            ,OH.InvoiceAmount
				,TMP.Recgrp
				,OH.Externorderkey 
      ORDER BY TMP.SeqNo

		
	 
      SELECT   SeqNo   
             ,  Orderkey     
             ,  Storerkey    
             ,  C_Cphone1   
             ,  C_Company       
             ,  CAddress       
             ,  Sdescr       
             ,  SKU          
             ,  C_Zip            
             ,  OrderDate     
             ,  Qty       
				 ,  RecGrp  
				 ,  ExtOrdkey 
				 ,  C01  
				 ,  C02 
				 ,  C03 
				 ,  C04 
				 ,  C05 
				 ,  C06 
				 ,  C07 
				 ,  C08 
				 ,  C09
				 ,  C10 
      FROM #TMP_HDR32
      ORDER BY SeqNo                    

      
      DROP TABLE #TMP_HDR32
      GOTO QUIT_SP


QUIT_SP:  
END       

GO