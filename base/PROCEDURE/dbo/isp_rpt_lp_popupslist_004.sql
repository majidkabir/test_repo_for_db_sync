SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_LP_POPUPSLIST_004                          */
/* Creation Date: 25-OCT-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-20380 - PH Mondelez Loading Guide			            */
/*                                                                      */
/* Called By: RPT_LP_POPUPSLIST_004                                     */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_LP_POPUPSLIST_004](
            @c_Loadkey     NVARCHAR(10)
			)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Storerkey	  NVARCHAR(15)	
		   , @c_Type        NVARCHAR(1) = '1'                      
         , @c_DataWindow  NVARCHAR(60) = 'RPT_LP_LOADSHEET_004'  
         , @c_RetVal      NVARCHAR(255)

    SELECT @c_Storerkey = ORDERS.Storerkey  
    FROM ORDERS (NOLOCK)  
    JOIN LOADPLANDETAIL(NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.ORDERKEY  
    WHERE LOADPLANDETAIL.Loadkey = @c_loadkey

	EXEC [dbo].[isp_GetCompanyInfo]    
       @c_Storerkey  = @c_Storerkey    
    ,  @c_Type       = @c_Type    
    ,  @c_DataWindow = @c_DataWindow    
    ,  @c_RetVal     = @c_RetVal           OUTPUT

   SELECT  LOADPLAN.Loadkey
			,	LOADPLAN.Facility
			,	LOADPLAN.Route
			,	LOADPLAN.CarrierKey
			,	LOADPLAN.TruckSize
			,	LOADPLAN.Driver
			,	ORDERS.Consigneekey
			,	ORDERS.C_Company
			,	ORDERS.C_Address1
			,	ORDERS.C_Address2
			,	ORDERS.C_Address3
			,	ORDERS.C_Address4
			,	ORDERS.C_City
			,	ORDERS.Externorderkey
			,	ORDERS.MBOLKey
			,	ORDERDETAIL.QtyAllocated
			,	ORDERDETAIL.QtyPicked
			,	STORER.Company
			,  PICKHEADER.PickHeaderKey
			,	PICKDETAIL.Storerkey
			,	PICKDETAIL.Sku 
			,	SKU.Descr
			,	UOM = CASE PICKDETAIL.UOM WHEN '1' THEN PACK.PACKUOM4
												  WHEN '2' THEN PACK.PACKUOM1
												  WHEN '3' THEN PACK.PACKUOM2
												  WHEN '6' THEN PACK.PACKUOM3
											  	  WHEN '7' THEN PACK.PACKUOM3
						END
			,	Qty = SUM(PICKDETAIL.QTY) 
			,  CBM = SUM(PICKDETAIL.Qty * SKU.StdCube)
			,	PACK.PackUOM1
			,	PACK.CaseCnt
			,	PACK.PackUOM2
			,	PACK.InnerPack
			,	PACK.PackUOM3
			,	PACK.PackUOM4
			,	PACK.Pallet
			,	LOTATTRIBUTE.Lottable02
			,	LOTATTRIBUTE.Lottable04
			,	Prepared = CONVERT(char(10), SUSER_NAME())  
			,	ReportType = ''
         ,  shelflife        = SKU.Shelflife 
         ,  Exp_date         = CASE WHEN ISNULL(SKU.Shelflife,0) = 0  THEN NULL ELSE LOTATTRIBUTE.Lottable04 + SKU.Shelflife END        
         ,  ShowExpDate      = CL1.Short 
         ,  LEXTLoadKey      = Loadplan.Externloadkey 
         ,  LPriority        = Loadplan.Priority 
         ,  LPuserdefDate01  = Loadplan.LPuserdefDate01
         ,  CL2.Description AS Copyname
         ,  CL2.Code AS Copycode
         ,  CL2.Short AS Copyshowcolumn
			--,  (CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(PICKDETAIL.Qty / PACK.CaseCnt) ELSE 0 END) AS CSE
         ,  (CASE WHEN PACK.CaseCnt > 0 THEN FLOOR((QtyPicked + ORDERDETAIL.QtyAllocated) / PACK.CaseCnt) ELSE 0 END) AS CSE
         --,	(ORDERDETAIL.QtyAllocated + QtyPicked) AS ZIN
			--,	(SELECT CAST(NULLIF((ORDERDETAIL.QtyAllocated + QtyPicked),0) AS INT) / CAST(NULLIF(PACK.InnerPack,0) AS INT) 
			--	FROM PACK P WITH (NOLOCK)
			--	JOIN ORDERDETAIL OD WITH (NOLOCK) ON P.InnerPack = OD.PackKey) AS ZIN
			,	(CASE WHEN PACK.InnerPack > 0 THEN (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) / PACK.InnerPack ELSE 0 END) AS ZIN
			,  (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked * PACK.InnerPack) AS Total_Eaches
			,	ISNULL(@c_RetVal,'') AS Logo
	FROM LOADPLAN WITH (NOLOCK)
	JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
	JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.orderkey = ORDERS.OrderKey) 
	JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)  
	JOIN PICKDETAIL   WITH (NOLOCK) ON  (ORDERS.Orderkey = PICKDETAIL.Orderkey)
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.OrderKey) AND (ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
	JOIN REFKEYLOOKUP WITH (NOLOCK) ON (PICKDETAIL.PickDetailKey = REFKEYLOOKUP.PickDetailKey)  
	JOIN PICKHEADER WITH (NOLOCK) ON (REFKEYLOOKUP.PickSlipNo = PICKHEADER.PickHeaderkey)
											AND(LOADPLAN.LoadKey = PICKHEADER.ExternOrderkey) 
	--JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLAN.LoadKey= PICKHEADER.ExternOrderKey)
	JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey) 
									AND(PICKDETAIL.Sku = SKU.Sku) 
	JOIN PACK WITH (NOLOCK) ON (ORDERDETAIL.Packkey = PACK.Packkey) 
	JOIN LOTATTRIBUTE WITH (NOLOCK) on (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) 
	LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'RPT_LP_POPUPSLIST_004'    
                                             AND CL1.Storerkey = ORDERS.StorerKey ) 
	LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCOPY' AND CL2.Long = 'RPT_LP_POPUPSLIST_004' AND CL2.Storerkey = ORDERS.StorerKey ) 
	WHERE LOADPLAN.Loadkey = @c_Loadkey  
    GROUP BY LOADPLAN.Loadkey
			,	LOADPLAN.Facility
			,	LOADPLAN.Route
			,	LOADPLAN.CarrierKey
			,	LOADPLAN.TruckSize
			,	LOADPLAN.Driver
			,	ORDERS.Consigneekey
			,	ORDERS.C_Company
			,	ORDERS.C_Address1
			,	ORDERS.C_Address2
			,	ORDERS.C_Address3
			,	ORDERS.C_Address4
			,	ORDERS.C_City
			,	ORDERS.Externorderkey
			,	ORDERS.MBOLKey
			,	ORDERDETAIL.QtyAllocated
			,	ORDERDETAIL.QtyPicked
			,	STORER.Company
			,   PICKHEADER.PickHeaderKey
			,	PICKDETAIL.Storerkey
			,	PICKDETAIL.Sku 
			,	SKU.Descr
			,	PICKDETAIL.UOM
		    ,	PACK.PackUOM1
			,	PACK.CaseCnt
			,	PACK.PackUOM2
			,	PACK.InnerPack
			,	PACK.PackUOM3
			,	PACK.PackUOM4
			,	PACK.Pallet
			,	LOTATTRIBUTE.Lottable02
			,	LOTATTRIBUTE.Lottable04
			,   SKU.Shelflife                    
			,   CL1.Short    
			,   Loadplan.Externloadkey 
			,   Loadplan.Priority 
			,   Loadplan.LPuserdefDate01   
            ,   CL2.Description
            ,   CL2.Code 
            ,   CL2.Short    
			,  (CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(PICKDETAIL.Qty / PACK.CaseCnt) ELSE 0 END)
			,	(CASE WHEN PACK.InnerPack > 0 THEN FLOOR(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) / PACK.InnerPack ELSE 0 END)
			,	ORDERDETAIL.QtyAllocated
			,	ORDERDETAIL.QtyPicked  
			,	PACK.InnerPack
			,	ISNULL(SKU.Altsku,'')
	ORDER BY PICKHEADER.PickHeaderKey
			,	ORDERS.ExternOrderkey
			,	PICKDETAIL.Storerkey
			,	PICKDETAIL.Sku

END -- procedure

GO