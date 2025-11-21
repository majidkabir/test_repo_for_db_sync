SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_sortlist11_1                                        */
/* Creation Date: 15-AUG-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-10276 - [PH] Unilever Loading Guide Report              */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_sortlist11_1]
           @c_Loadkey         NVARCHAR(10)
         , @c_ReportType      NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_RptByODUOM       NVARCHAR(10) = 'N'

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF OBJECT_ID('tempdb..#TMP_RDTDATA','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_RDTDATA;
   END

   CREATE TABLE #TMP_RDTDATA
        (   RowID             INT   IDENTITY(1,1)  PRIMARY KEY
        ,   Loadkey           NVARCHAR(10)   NOT NULL DEFAULT('')
        ,   Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('')
        ,   OrderLineNumber   NVARCHAR(10)   NOT NULL DEFAULT('')  
        ,   PickDetailKey     NVARCHAR(10)   NOT NULL DEFAULT('')            
        ,   UOM               NVARCHAR(10)   NOT NULL DEFAULT('')  
        ,   Lottable02        NVARCHAR(18)   NOT NULL DEFAULT('')  
        ,   Lottable04        DATETIME       NOT NULL  
        )

   SET @c_Storerkey = ''         
   SELECT TOP 1 @c_Storerkey = OH.Storerkey
   FROM LOADPLANDETAIL LP WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK)
      ON LP.Orderkey = OH.Orderkey
   WHERE LP.Loadkey = @c_Loadkey
   ORDER BY LP.LoadLineNumber

   SET @c_RptByODUOM = 'N'
   SELECT @c_RptByODUOM = CASE WHEN IsNull(CL.Short, 'N') <> 'N' THEN 'Y' ELSE 'N' END
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'REPORTCFG' 
   AND CL.Code = 'RptByODUOM'
   AND CL.Long = 'r_dw_sortlist11' 
   AND CL.Storerkey = @c_Storerkey

   IF @c_RptByODUOM = 'Y'
   BEGIN
      INSERT INTO #TMP_RDTDATA
      (  Loadkey
      ,  Orderkey
      ,  OrderLineNumber
      ,  PickDetailKey
      ,  UOM
      ,  Lottable02
      ,  Lottable04
      )
      SELECT DISTINCT
         @c_Loadkey
      ,  OD.Orderkey
      ,  OD.OrderLineNumber
      ,  PD.PickDetailKey
      ,  OD.UOM
      ,  ISNULL(LA.Lottable02,'')
      ,  Lottable04 = CASE WHEN CONVERT(NVARCHAR(8), LA.Lottable04, 112) = '19000101' THEN NULL ELSE LA.Lottable04 END       
      FROM LOADPLANDETAIL LP WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK)
         ON LP.Orderkey = OD.Orderkey
      JOIN PICKDETAIL PD WITH (NOLOCK)
         ON  OD.Orderkey = PD.Orderkey
         AND OD.OrderLineNumber = PD.OrderLineNumber
      JOIN LOTATTRIBUTE LA WITH (NOLOCK)
         ON PD.Lot = LA.Lot
      WHERE LP.Loadkey = @c_Loadkey
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_RDTDATA
      (  Loadkey
      ,  Orderkey
      ,  OrderLineNumber
      ,  PickDetailKey
      ,  UOM
      ,  Lottable02
      ,  Lottable04
      )
      SELECT DISTINCT
         @c_Loadkey
      ,  PD.Orderkey
      ,  PD.OrderLineNumber
      ,  PD.PickDetailKey
      ,  PD.UOM 
      ,  ISNULL(LA.Lottable02,'')
      ,  Lottable04 = CASE WHEN CONVERT(NVARCHAR(8), LA.Lottable04, 112) = '19000101' THEN NULL ELSE LA.Lottable04 END
      FROM LOADPLANDETAIL LP WITH (NOLOCK)
      JOIN PICKDETAIL PD WITH (NOLOCK)
         ON LP.Orderkey = PD.Orderkey
      JOIN LOTATTRIBUTE LA WITH (NOLOCK)
         ON PD.Lot = LA.Lot
      WHERE LP.Loadkey = @c_Loadkey
   END

QUIT_SP:   
   SELECT   LOADPLAN.Loadkey
			,	LOADPLAN.Facility
			,	[Route]     = ISNULL(LOADPLAN.[Route],'')
			,	CarrierKey  = ISNULL(LOADPLAN.CarrierKey,'')
			,	TruckSize   = ISNULL(LOADPLAN.TruckSize,'')
			,	Driver      = ISNULL(LOADPLAN.Driver,'')
			,	Consigneekey= ISNULL(ORDERS.Consigneekey,'')
			,	C_Company   = ISNULL(ORDERS.C_Company,'')
			,	C_Address1  = ISNULL(ORDERS.C_Address1,'')
			,	C_Address2  = ISNULL(ORDERS.C_Address2,'')
			,	C_Address3  = ISNULL(ORDERS.C_Address3,'')
			,	C_Address4  = ISNULL(ORDERS.C_Address4,'')
			,	C_City      = ISNULL(ORDERS.C_City,'')
			,	Externorderkey = ISNULL(ORDERS.Externorderkey,'')
			,	Company     = ISNULL(STORER.Company,'')
			,  PICKHEADER.PickHeaderKey
			,	PICKDETAIL.Storerkey
			,	PICKDETAIL.Sku 
			,	Descr       = ISNULL(SKU.Descr,'')
			,	UOM  = CASE WHEN @c_RptByODUOM = 'Y' THEN T.UOM
                        WHEN T.UOM = '1' THEN PACK.PACKUOM4
							   WHEN T.UOM = '2' THEN PACK.PACKUOM1
								WHEN T.UOM = '3' THEN PACK.PACKUOM2
								WHEN T.UOM = '6' THEN PACK.PACKUOM3
								WHEN T.UOM = '7' THEN PACK.PACKUOM3
                        ELSE ''
						END
			,	Qty = ISNULL(SUM(PICKDETAIL.QTY),0) 
			,  CBM = ISNULL(SUM(PICKDETAIL.Qty * SKU.StdCube),0.00)
			,	PACK.PackUOM1
			,	PACK.CaseCnt
			,	PACK.PackUOM2
			,	PACK.InnerPack
			,	PACK.PackUOM3
			,	PACK.PackUOM4
			,	PACK.Pallet
			,	T.Lottable02  
			,	T.Lottable04  
			,	Prepared    = CONVERT(char(10), SUSER_NAME())  
			,	ReportType  = CAST(@c_reporttype as char(3)) 
         ,  shelflife   = ISNULL(SKU.Shelflife,0) 
         ,  Exp_date    = CASE WHEN ISNULL(SKU.Shelflife,0) = 0 THEN NULL 
                               WHEN T.Lottable04 IS NULL THEN NULL 
                               ELSE T.Lottable04 + ISNULL(SKU.Shelflife,0) END        
         ,  ShowExpDate = ISNULL(CL1.Short,'') 
         ,  LEXTLoadKey = ISNULL(Loadplan.Externloadkey,'') 
         ,  LPriority   = ISNULL(Loadplan.[Priority],'') 
         ,  LPuserdefDate01= CASE WHEN CONVERT(NVARCHAR(8), Loadplan.LPuserdefDate01, 112) = '19000101' THEN NULL ELSE Loadplan.LPuserdefDate01 END  
	FROM #TMP_RDTDATA T  
   JOIN LOADPLAN WITH (NOLOCK) ON (T.Loadkey = LOADPLAN.Loadkey)
	JOIN ORDERS WITH (NOLOCK) ON (T.orderkey = ORDERS.OrderKey) 
	JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey) 
	JOIN PICKDETAIL   WITH (NOLOCK) ON  (ORDERS.Orderkey = PICKDETAIL.Orderkey)
                                   AND (PICKDETAIL.PickDetailkey = T.PickDetailKey)                                  
	JOIN REFKEYLOOKUP WITH (NOLOCK) ON  (PICKDETAIL.PickDetailKey = REFKEYLOOKUP.PickDetailKey)  
	JOIN PICKHEADER WITH (NOLOCK) ON (REFKEYLOOKUP.PickSlipNo = PICKHEADER.PickHeaderkey)
											AND(LOADPLAN.LoadKey= PICKHEADER.ExternOrderkey) 
	JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey) 
									AND(PICKDETAIL.Sku = SKU.Sku) 
	JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'r_dw_sortlist11'    
                                        AND CL1.Storerkey = ORDERS.StorerKey ) 
	WHERE loadplan.loadkey = @c_Loadkey  
   GROUP BY LOADPLAN.Loadkey
			,	LOADPLAN.Facility
			,	ISNULL(LOADPLAN.[Route],'')
			,	ISNULL(LOADPLAN.CarrierKey,'')
			,	ISNULL(LOADPLAN.TruckSize,'')
			,	ISNULL(LOADPLAN.Driver,'')
			,	ISNULL(ORDERS.Consigneekey,'')
			,	ISNULL(ORDERS.C_Company,'')
			,	ISNULL(ORDERS.C_Address1,'')
			,	ISNULL(ORDERS.C_Address2,'')
			,	ISNULL(ORDERS.C_Address3,'')
			,	ISNULL(ORDERS.C_Address4,'')
			,	ISNULL(ORDERS.C_City,'')
			,	ISNULL(ORDERS.Externorderkey,'')
			,	ISNULL(STORER.Company,'')
			,  PICKHEADER.PickHeaderKey
			,	PICKDETAIL.Storerkey
			,	PICKDETAIL.Sku 
			,	ISNULL(SKU.Descr,'')
			,	T.UOM
		   ,	PACK.PackUOM1
			,	PACK.CaseCnt
			,	PACK.PackUOM2
			,	PACK.InnerPack
			,	PACK.PackUOM3
			,	PACK.PackUOM4
			,	PACK.Pallet
			,	T.Lottable02 
			,	T.Lottable04  
         ,  ISNULL(SKU.Shelflife,0)                
         ,  ISNULL(CL1.Short,'')   
         ,  ISNULL(Loadplan.Externloadkey,'') 
         ,  ISNULL(Loadplan.[Priority],'') 
         ,  CASE WHEN CONVERT(NVARCHAR(8), Loadplan.LPuserdefDate01, 112) = '19000101' THEN NULL ELSE Loadplan.LPuserdefDate01 END               
	ORDER BY PICKHEADER.PickHeaderKey
			,	ISNULL(ORDERS.Externorderkey,'')
			,	PICKDETAIL.Storerkey
			,	PICKDETAIL.Sku

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO