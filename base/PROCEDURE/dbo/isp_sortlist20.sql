SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* StoredProc: isp_sortlist20                                           */
/* Creation Date: 10-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-7783 - PH ALCON Loading Guide                           */
/*        :                                                             */
/* Called By: r_dw_sortlist20                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_sortlist20] 
            @c_Loadkey     NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT = 1
         
         , @c_SQL             NVARCHAR(4000)
         , @c_SQLArgument     NVARCHAR(4000)

         , @c_Storerkey       NVARCHAR(15)

         , @n_SortBySKU       INT

         , @c_lottable02label NVARCHAR(60)
         , @c_lottable04label NVARCHAR(60)

         , @c_AllowZeroQTY   NVARCHAR(1) 

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #Temp_SortList20 (
   Loadkey         NVARCHAR(10),
   Facility        NVARCHAR(5),
   [Route]         NVARCHAR(10),
   CarrierKey      NVARCHAR(15),
   TruckSize       NVARCHAR(10),
   Driver          NVARCHAR(45),
   Consigneekey    NVARCHAR(15),
   C_Company       NVARCHAR(45),
   C_Address1      NVARCHAR(45),
   C_Address2      NVARCHAR(45),
   C_Address3      NVARCHAR(45),
   C_Address4      NVARCHAR(45),
   C_City          NVARCHAR(45),
   Externorderkey  NVARCHAR(50),
   Company         NVARCHAR(45),
   PickHeaderKey   NVARCHAR(18),
   Storerkey       NVARCHAR(15),
   Sku             NVARCHAR(20),
   DESCR           NVARCHAR(60),
   UOM             NVARCHAR(10),
   Qty             INT,
   CBM             INT,
   PackUOM1        NVARCHAR(10),
   CaseCnt         INT,
   PackUOM2        NVARCHAR(10),
   InnerPack       INT,
   PackUOM3        NVARCHAR(10),
   PackUOM4        NVARCHAR(10),
   Pallet          INT,
   Lottable02      NVARCHAR(18),
   Lottable04      NVARCHAR(30),
   Prepared        NVARCHAR(10),
   shelflife       INT,
   Exp_date        DATETIME,
   ShowExpDate     NVARCHAR(10),
   LEXTLoadKey     NVARCHAR(30),
   LPriority       NVARCHAR(10),
   LPuserdefDate01 DATETIME,
   Lottable06      NVARCHAR(30),
   AllowZeroQty    NVARCHAR(10),
   copyname        NVARCHAR(250),
   copycode        NVARCHAR(30),
   copyshowcolumn  NVARCHAR(10),
   IsParentSKU     NVARCHAR(10)
   )

   INSERT INTO #Temp_SortList20
   SELECT   LOADPLAN.Loadkey
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
			,	LOTTABLE04 = CONVERT(NVARCHAR, LOTATTRIBUTE.LOTTABLE04,103)
			,	Prepared = CONVERT(char(10), SUSER_NAME())  
         ,  shelflife        = SKU.Shelflife 
         ,  Exp_date         = CASE WHEN ISNULL(SKU.Shelflife,0) = 0  THEN NULL ELSE LOTATTRIBUTE.Lottable04 + SKU.Shelflife END        
         ,  ShowExpDate      = CL1.Short 
         ,  LEXTLoadKey      = Loadplan.Externloadkey 
         ,  LPriority        = Loadplan.Priority 
         ,  LPuserdefDate01  = Loadplan.LPuserdefDate01
         ,  Lottable06 = LOTATTRIBUTE.Lottable06
         ,  AllowZeroQty = ISNULL(CL2.SHORT,'')
         ,  PG.Description AS copyname
         ,  PG.Code AS copycode
         ,  PG.Short AS copyshowcolumn
         ,  CASE WHEN (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) = 0 THEN 'Parent' ELSE '' END
	FROM LOADPLAN WITH (NOLOCK)
	JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
	JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.orderkey = ORDERS.OrderKey) 
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.orderkey = ORDERS.OrderKey)
	JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)  
	JOIN PICKDETAIL   WITH (NOLOCK) ON  (ORDERS.Orderkey = PICKDETAIL.Orderkey) AND (ORDERDETAIL.ORDERLINENUMBER = PICKDETAIL.ORDERLINENUMBER)
	JOIN REFKEYLOOKUP WITH (NOLOCK) ON (PICKDETAIL.PickDetailKey = REFKEYLOOKUP.PickDetailKey)  
	JOIN PICKHEADER WITH (NOLOCK) ON (REFKEYLOOKUP.PickSlipNo = PICKHEADER.PickHeaderkey)
											AND(LOADPLAN.LoadKey= PICKHEADER.ExternOrderkey) 
	JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey) 
									AND(PICKDETAIL.Sku = SKU.Sku) AND (ORDERDETAIL.SKU = SKU.SKU)
	JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
	JOIN LOTATTRIBUTE WITH (NOLOCK) on (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) 
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'r_dw_sortlist20'    
                                             AND CL1.Storerkey = ORDERS.StorerKey ) 
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCFG' AND CL2.Code = 'ShowZeroQty' AND CL2.Long = 'r_dw_sortlist20'    
                                             AND CL2.Storerkey = ORDERS.StorerKey AND CL2.SHORT IN ('Y','N') ) 
   LEFT JOIN CODELKUP PG WITH (NOLOCK) ON (PG.LISTNAME = 'REPORTCOPY' AND PG.LONG = 'r_dw_sortlist20' AND PG.STORERKEY = ORDERS.STORERKEY)
	WHERE loadplan.loadkey = @c_Loadkey AND (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) > 0
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
			,	STORER.Company
			,  PICKHEADER.PickHeaderKey
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
			,  SKU.Shelflife
			,  CL1.Short
			,  Loadplan.Externloadkey
			,  Loadplan.Priority 
			,  Loadplan.LPuserdefDate01 
			,  LOTATTRIBUTE.Lottable06
			,  ISNULL(CL2.SHORT,'')   
         ,  PG.Description
         ,  PG.Code
         ,  PG.Short
         ,  CASE WHEN (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) = 0 THEN 'Parent' ELSE '' END
    --HAVING SUM(ORDERDETAIL.ShippedQty) >= CASE ISNULL(CL2.SHORT,'')
    --WHEN 'N' THEN 1 ELSE 0 END              
    UNION ALL
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
			,	STORER.Company
			,  NULL--PICKHEADER.PickHeaderKey
			,	ORDERS.Storerkey
			,	ORDERDETAIL.Sku 
			,	SKU.Descr
			,	UOM = 'EA'
			,	Qty = 0
			,   CBM = 0
			,	PACK.PackUOM1
			,	PACK.CaseCnt
			,	PACK.PackUOM2
			,	PACK.InnerPack
			,	PACK.PackUOM3
			,	PACK.PackUOM4
			,	PACK.Pallet
			,	Lottable02 = ''
			,	Lottable04 = '00/00/0000'
			,	Prepared = CONVERT(char(10), SUSER_NAME())  
         ,  shelflife        = SKU.Shelflife 
         ,  Exp_date         = ''
         ,  ShowExpDate      = CL1.Short 
         ,  LEXTLoadKey      = Loadplan.Externloadkey 
         ,  LPriority        = Loadplan.Priority 
         ,  LPuserdefDate01  = Loadplan.LPuserdefDate01
         ,  Lottable06 = ''
         ,  AllowZeroQty = ISNULL(CL2.SHORT,'')
         ,  PG.Description AS copyname
         ,  PG.Code AS copycode
         ,  PG.Short AS copyshowcolumn
         ,  CASE WHEN (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) = 0 THEN 'Parent' ELSE '' END
	FROM LOADPLAN WITH (NOLOCK)
	JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
	JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.orderkey = ORDERS.OrderKey) 
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.orderkey = ORDERS.OrderKey)
	JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)  
	--JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLAN.LoadKey= PICKHEADER.ExternOrderkey) 
	JOIN SKU WITH (NOLOCK)  ON (ORDERS.StorerKey = SKU.StorerKey) 
									AND (ORDERDETAIL.SKU = SKU.SKU)
	JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'r_dw_sortlist20'    
                                             AND CL1.Storerkey = ORDERS.StorerKey ) 
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCFG' AND CL2.Code = 'ShowZeroQty' AND CL2.Long = 'r_dw_sortlist20'    
                                             AND CL2.Storerkey = ORDERS.StorerKey AND CL2.SHORT IN ('Y','N') ) 
   LEFT JOIN CODELKUP PG WITH (NOLOCK) ON (PG.LISTNAME = 'REPORTCOPY' AND PG.LONG = 'r_dw_sortlist20' AND PG.STORERKEY = ORDERS.STORERKEY)
   LEFT JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
	WHERE loadplan.loadkey = @c_Loadkey AND (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) = 0
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
			,	STORER.Company
			--,  PICKHEADER.PickHeaderKey
			,	ORDERS.Storerkey
			,	ORDERDETAIL.Sku 
			,	SKU.Descr
		   ,	PACK.PackUOM1
			,	PACK.CaseCnt
			,	PACK.PackUOM2
			,	PACK.InnerPack
			,	PACK.PackUOM3
			,	PACK.PackUOM4
			,	PACK.Pallet
			,  SKU.Shelflife
			,  CL1.Short
			,  Loadplan.Externloadkey
			,  Loadplan.Priority 
			,  Loadplan.LPuserdefDate01 
			,  ISNULL(CL2.SHORT,'')   
         ,  PG.Description
         ,  PG.Code
         ,  PG.Short
         ,  CASE WHEN (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) = 0 THEN 'Parent' ELSE '' END
   --HAVING SUM(ORDERDETAIL.ShippedQty) >= CASE ISNULL(CL2.SHORT,'')
   --WHEN 'N' THEN 1 ELSE 0 END   
	ORDER BY PG.Code
         ,  PICKHEADER.PickHeaderKey
			,	ORDERS.ExternOrderkey
			,	PICKDETAIL.Storerkey
			,	PICKDETAIL.Sku

   --Get Codelkup.Short value from TempData
   SELECT TOP 1 @c_AllowZeroQTY = AllowZeroQty
   FROM #Temp_SortList20

   IF ( (@n_continue = 1 OR @n_continue = 2) AND (ISNULL(@c_AllowZeroQTY,'') <> '' AND ISNULL(@c_AllowZeroQTY,'') = 'N') )
   BEGIN
      SELECT * FROM #Temp_SortList20 WHERE IsParentSKU <> 'Parent'
   END

   IF ( (@n_continue = 1 OR @n_continue = 2) AND (ISNULL(@c_AllowZeroQTY,'') <> '' AND ISNULL(@c_AllowZeroQTY,'') = 'Y') )
   BEGIN
      SELECT * FROM #Temp_SortList20 
   END
   
   IF ( (@n_continue = 1 OR @n_continue = 2) AND (ISNULL(@c_AllowZeroQTY,'') = '' AND ISNULL(@c_AllowZeroQTY,'') NOT IN ('Y','N')) )
   BEGIN
      SELECT * FROM #Temp_SortList20
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO