SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_packing_list_24_rpt                                */
/* Creation Date: 11-Aug-2016                                              */
/* Copyright: LF                                                           */
/* Written by: CSCHONG                                                     */
/*                                                                         */
/* Purpose:  SOS#374757 - CN Swire Ecom Packing List                       */
/*                                                                         */
/* Called By: PB: r_dw_packing_list_24_rpt                                 */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/***************************************************************************/
CREATE PROC [dbo].[isp_packing_list_24_rpt]
           @c_Orderkey    NVARCHAR(10) 

AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_Storerkey       NVARCHAR(15)
   
   
   
      CREATE TABLE #TMP_PackingList24
            (  Orderkey                  NVARCHAR(50) NULL
            ,  loadkey                   NVARCHAR(20) NULL
            ,  ExternOrderkey            NVARCHAR(50) NULL  --tlting_ext  
            ,  MCompany                  NVARCHAR(45) NULL
            ,  C_Contact1                NVARCHAR(45) NULL
            ,  CAddress                  NVARCHAR(90) NULL
            ,  Shipperkey                NVARCHAR(20) NULL
            ,  CPhone1                   NVARCHAR(20) NULL
            ,  Orddate                   NVARCHAR(10) NULL
            ,  PLoc                      NVARCHAR(10) NULL
            ,  SKU                       NVARCHAR(20) NULL
            ,  Style                     NVARCHAR(20) NULL
            ,  SColor                    NVARCHAR(10) NULL
            ,  S_SIZE                    NVARCHAR(10) NULL
            ,  MSku                      NVARCHAR(20) NULL
            ,  PQty                      INT
            )
   INSERT INTO #TMP_PackingList24 ( Orderkey       
											,  loadkey        
											,  ExternOrderkey 
											,  MCompany       
											,  C_Contact1     
											,  CAddress       
											,  Shipperkey     
											,  CPhone1        
											,  Orddate        
											,  PLoc           
											,  SKU            
											,  Style          
											,  SColor         
											,  S_SIZE         
											,  MSku           
											,  PQty           
											)
      SELECT DISTINCT ORD.OrderKey,ORD.LoadKey,ORD.ExternOrderKey,ISNULL(ORD.M_Company,''),ORd.C_Contact1,
		(Ord.c_city + Char(10) + Ord. C_Address1),ORD.Shipperkey,ORD.C_Phone1,CONVERT(NVARCHAR(10),ORD.OrderDate,111),
		PD.Loc,PD.Sku,S.style,s.Color,size,ISNULL(s.MANUFACTURERSKU,''),sum(pd.qty)
		FROM Orders ORD WITH (NOLOCK) 
		JOIN PICKDETAIL PD WITH (NOLOCK) ON ORD.OrderKey = PD.OrderKey 
		JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey=PD.StorerKey
		WHERE Ord.OrderKey=@c_Orderkey
		GROUP BY  ORD.OrderKey,ORD.LoadKey,ORD.ExternOrderKey,ORD.M_Company,ORd.C_Contact1,
		(Ord.c_city + Char(10) + Ord. C_Address1),ORD.Shipperkey,ORD.C_Phone1,CONVERT(NVARCHAR(10),ORD.OrderDate,111),
		PD.Loc,PD.Sku,S.style,s.Color,size,s.MANUFACTURERSKU

  SELECT * FROM #TMP_PackingList24
  ORDER BY orderkey,Sku

END

SET QUOTED_IDENTIFIER OFF 

GO