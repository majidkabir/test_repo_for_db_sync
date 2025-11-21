SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_pod_24                                         */  
/* Creation Date: 27/12/2018                                            */  
/* Copyright: IDS                                                       */  
/* Written by: WLCHOOI                                                  */  
/*                                                                      */  
/* Purpose: WMS-7362 - CN_SwellFun_pod_CR                               */  
/*                                                                      */  
/* Called By: isp_pod_24                                                */   
/*                                                                      */  
/* Parameters: (Input)  @c_mbolkey   = MBOL No                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver. Purposes                                 */ 
/************************************************************************/  

CREATE PROCEDURE [dbo].[isp_pod_24] 
        @c_mbolkey NVARCHAR(10)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   CREATE TABLE #TMP_POD24(
	MBOLKEY			NVARCHAR(10) NULL
	,OrderDate		DATETIME
	,ExternOrderkey	NVARCHAR(60) NULL
	,ST_Address1	NVARCHAR(60) NULL
	,F_Contact1		NVARCHAR(60) NULL
	,F_Phone1		NVARCHAR(30) NULL
	,C_Company		NVARCHAR(60) NULL
	,C_Contact1		NVARCHAR(60) NULL
	,C_Addresses	NVARCHAR(200) NULL
	,C_Phone		NVARCHAR(60) NULL
	,C_City			NVARCHAR(60) NULL
	,C_State		NVARCHAR(60) NULL
	,SKU			NVARCHAR(40) NULL
	,SKUDescr		NVARCHAR(60) NULL
	,Qty			INT
	,ST_Contact1	NVARCHAR(60) NULL
	,ST_Phone1		NVARCHAR(30) NULL
	,Lottable02		NVARCHAR(36) NULL
	,StdCube			FLOAT
   )

   INSERT INTO #TMP_POD24 (MBOLKEY,OrderDate,ExternOrderkey,ST_Address1,F_Contact1,F_Phone1,C_Company,C_Contact1
							,C_Addresses,C_Phone,C_City,C_State,SKU,SKUDescr,Qty,ST_Contact1,ST_Phone1,Lottable02,StdCube)
   SELECT DISTINCT MBOL.Mbolkey
			,Orders.OrderDate
			,Orders.Externorderkey
			,Storer.Address1
			,Facility.Contact1
			,Facility.Phone1
			,ISNULL(Orders.C_Company,'')
			,ISNULL(Orders.C_Contact1,'')
			,trim(Orders.C_Address1)+' '+trim(Orders.C_Address2)+' '+trim(Orders.C_Address3)+' '+trim(Orders.C_Address4)
			,trim(Orders.C_phone1)+' '+trim(Orders.C_Phone2)
			,ISNULL(Orders.C_City,'')
			,ISNULL(Orders.C_State,'')
			,trim(Pickdetail.sku)
			,trim(Sku.Descr)
			,SUM(pickdetail.qty)
			,Storer.Contact1
			,Storer.Phone1
			,LOTATTRIBUTE.Lottable02
			,SKU.StdCube
	FROM ORDERS (NOLOCK)
	JOIN MBOL (NOLOCK) ON MBOL.Mbolkey = Orders.Mbolkey
	JOIN FACILITY (NOLOCK) ON FACILITY.FACILITY = ORDERS.FACILITY
	JOIN STORER (NOLOCK) ON ORDERS.STORERKEY = STORER.STORERKEY
	JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.ORDERKEY = ORDERS.ORDERKEY
	JOIN SKU (NOLOCK) ON SKU.SKU = PICKDETAIL.SKU AND PICKDETAIL.STORERKEY = SKU.STORERKEY
	JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.LOT = LOTATTRIBUTE.LOT
	WHERE MBOL.MBOLKEY = @c_mbolkey
	GROUP BY
	MBOL.Mbolkey
	,Orders.OrderDate
	,Orders.Externorderkey
	,Storer.Address1
	,Facility.Contact1
	,Facility.Phone1
	,ISNULL(Orders.C_Company,'')
	,ISNULL(Orders.C_Contact1,'')
	,trim(Orders.C_Address1)+' '+trim(Orders.C_Address2)+' '+trim(Orders.C_Address3)+' '+trim(Orders.C_Address4)
	,trim(Orders.C_phone1)+' '+trim(Orders.C_Phone2)
	,ISNULL(Orders.C_City,'')
	,ISNULL(Orders.C_State,'')
	,Pickdetail.sku
	,Sku.Descr
	,Storer.Contact1
	,Storer.Phone1
  ,LOTATTRIBUTE.Lottable02
  ,SKU.StdCube


	SELECT MBOLKEY
	,OrderDate	
	,ExternOrderkey	
	,ST_Address1
	,F_Contact1		
	,F_Phone1	
	,C_Company	
	,C_Contact1	
	,C_Addresses
	,C_Phone
	,C_City		
	,C_State				
	,ST_Contact1	
	,ST_Phone1
	,SKU
	,SKUDescr
	,Qty		 
	,Lottable02
  ,StdCube
  FROM #TMP_POD24
  GROUP BY
  MBOLKEY
	,OrderDate	
	,ExternOrderkey	
	,ST_Address1
	,F_Contact1		
	,F_Phone1	
	,C_Company	
	,C_Contact1	
	,C_Addresses
	,C_Phone
	,C_City		
	,C_State				
	,ST_Contact1	
	,ST_Phone1
	,SKU
	,SKUDescr
	,Qty		 
	,Lottable02
  ,StdCube

END

GO