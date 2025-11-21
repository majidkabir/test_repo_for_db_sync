SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_inventory_alloc_rpt                            */
/* Creation Date: 24-APR-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-4579 - CN NIKE One Inventory WMS Report                */
/*                                                                      */
/* Input Parameters: loadkey                                            */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: r_inventory_alloc_rpt                                     */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_inventory_alloc_rpt] (
         @c_storerkey         NVARCHAR(20)
        ,@c_Facility          NVARCHAR(10)
        ,@d_OrderDateStart    DATETIME
        ,@d_OrderDateEnd      DATETIME
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE  @c_PickSlipNo      NVARCHAR(20)           
	       

  CREATE TABLE #TMP_AllocRpt (
          rowid           int identity(1,1),
          Pickslipno      NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          OHPriority      NVARCHAR(10) NULL,
          IntVehicle      NVARCHAR(30) NULL,
          LoadDate        NVARCHAR(10) NULL,
          consigneekey    NVARCHAR(45) NULL,
          City            NVARCHAR(45) NULL,
          Address2        NVARCHAR(45) NULL,
          Address3        NVARCHAR(45) NULL,
          Company         NVARCHAR(45) NULL,
          OHSTOP          NVARCHAR(10) NULL,
          ORDQty          INT,
          BZQty           INT,
          CRWQty          INT,
          CRWPQty         INT,
          OFFQty          INT,
          PDQty           INT, 
			 QTYAlloc        INT)           
                                                           

  
 	INSERT INTO #TMP_AllocRpt( Pickslipno,loadkey,
										OHPriority,
										IntVehicle,
										LoadDate,
										consigneekey,
										City,
										Address2,
										Address3,
										Company,
										OHSTOP,
										ORDQty,
										BZQty,
										CRWQty,
										CRWPQty,
										OFFQty,
										PDQty, 
										QTYAlloc) 
			SELECT  PH.PickHeaderKey AS PSlipno,OH.loadkey,OH.[Priority] AS OHPriority,OH.intermodalvehicle,
			        LP.AddDate AS LDate,OH.ConsigneeKey,OH.C_City,ISNULL(OH.C_Address2,''),
			        ISNULL(OH.C_Address3,''),ISNULL(OH.C_Company,''),OH.[Stop] AS OHSTOP,
			SUM(OD.OriginalQty) AS ORDQty,
			CASE WHEN C.Code = 'BZ' THEN SUM(PID.Qty) ELSE 0 END AS BZQty,
			CASE WHEN C.Code = 'CRW' THEN SUM(PID.Qty) ELSE 0 END AS CRWQty,
			--CASE WHEN C.Code = 'PLUS' THEN SUM(PID.Qty) ELSE 0 END AS PLUSQty,
			CASE WHEN C.Code = 'CRWP' THEN SUM(PID.Qty) ELSE 0 END AS PLUSQty,
			CASE WHEN C.Code = 'OFF' THEN SUM(PID.Qty) ELSE 0 END AS OFFQty,
			SUM(OD.QtyPicked) AS pqty,SUM(OD.QtyAllocated) AS QtyAllc
			FROM ORDERS OH WITH (NOLOCK)
			JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey
			JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = OH.LoadKey
			JOIN PICKHEADER PH WITH (NOLOCK) ON PH.externorderkey = OH.LoadKey
			JOIN (select OrderKey,OrderLineNumber,Loc,sum(qty) as qty from pickdetail (nolock) where OrderKey in (select orderkey from orders (nolock) where StorerKey = @c_storerkey
         AND Facility = @c_Facility
         AND AddDate >= @d_OrderDateStart and AddDate <= @d_OrderDateEnd)
			Group by OrderKey,OrderLineNumber,Loc
			) PID ON PID.OrderKey=OD.OrderKey AND PID.OrderLineNumber=OD.OrderLineNumber
			JOIN LOC L WITH (NOLOCK) ON L.loc = PID.Loc
			LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME='ALLSorting' AND C.code2 = L.PickZone
			WHERE OH.StorerKey = @c_storerkey
         AND OH.Facility = @c_Facility
         AND OH.AddDate >= @d_OrderDateStart 
         AND OH.AddDate <= @d_OrderDateEnd
         GROUP BY  OH.[Stop] , OH.loadkey,PH.PickHeaderKey ,LP.AddDate ,OH.ConsigneeKey,
         OH.[Priority] ,OH.intermodalvehicle,OH.C_City,ISNULL(OH.C_Company,''),ISNULL(OH.C_Address3,''),
         C.Code,ISNULL(OH.C_Address2,'')
			ORDER BY OH.loadkey,PH.PickHeaderKey,OH.[Stop]
   
  

	SELECT   Pickslipno,
	         loadkey,
			   OHPriority,
			   IntVehicle,
				LoadDate,
				consigneekey,
				City,
				Address2,
				Address3,
				Company,
				OHSTOP,
				ORDQty,
				BZQty,
				CRWQty,
				CRWPQty,
				OFFQty,
				PDQty, 
				QTYAlloc
	FROM #TMP_AllocRpt
	ORDER BY loadkey,pickslipno,OHStop
	    
   --END
END


GO