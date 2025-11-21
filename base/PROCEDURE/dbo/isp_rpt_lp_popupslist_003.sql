SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_LP_POPUPSLIST_003                          */
/* Creation Date: 12-OCT-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-20380 - PH IDSMED Loading Guide Modification            */
/*          Copy and modify from isp_sortlist28                         */
/*                                                                      */
/* Called By: RPT_LP_POPUPSLIST_003                                     */
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
CREATE   PROC [dbo].[isp_RPT_LP_POPUPSLIST_003](
            @c_Loadkey     NVARCHAR(10)
			)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT = 1
         
         , @c_SQL             NVARCHAR(4000)
         , @c_SQLArgument     NVARCHAR(4000)

         , @c_Storerkey       NVARCHAR(15)

         , @n_SortBySKU       INT

         , @c_lottable02label NVARCHAR(60)
         , @c_lottable04label NVARCHAR(60)

         , @c_AllowZeroQTY   NVARCHAR(1)
		 , @c_recgroup        INT
		 , @c_Type        NVARCHAR(1) = '1'                      
         , @c_DataWindow  NVARCHAR(60) = 'RPT_LP_POPUPSLIST_003'  
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
	  Notes			  NVARCHAR(255),
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
      IsParentSKU     NVARCHAR(10),
      OrderGroup      NVARCHAR(20),
      Lottable08      NVARCHAR(30),
      Lottable10      NVARCHAR(30),
      Lottable12      NVARCHAR(30),
      SKUGroup        NVARCHAR(10) NULL,
      ITEMCLASS       NVARCHAR(10) NULL,
	  Wavekey		  NVARCHAR(10),
	  LOGO		      NVARCHAR(255)	
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
			,	ORDERS.Notes
			,	STORER.Company
			,   PICKHEADER.PickHeaderKey
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
			,   CBM = SUM(PICKDETAIL.Qty * SKU.StdCube)
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
			,   shelflife        = SKU.Shelflife 
			,   Exp_date         = CASE WHEN ISNULL(SKU.Shelflife,0) = 0  THEN NULL ELSE LOTATTRIBUTE.Lottable04 + SKU.Shelflife END        
			,   ShowExpDate      = CL1.Short 
			,   LEXTLoadKey      = Loadplan.Externloadkey 
			,   LPriority        = Loadplan.Priority 
			,   LPuserdefDate01  = Loadplan.LPuserdefDate01
			,   Lottable06 = LOTATTRIBUTE.Lottable06
			,   AllowZeroQty = ISNULL(CL2.SHORT,'')
			,   PG.Description AS copyname
			,   PG.Code AS copycode
			,   PG.Short AS copyshowcolumn
			,   CASE WHEN (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) = 0 THEN 'Parent' ELSE '' END
			,   ORDERS.OrderGroup
			,	LOTATTRIBUTE.Lottable08
			,	LOTATTRIBUTE.Lottable10
			,	LOTATTRIBUTE.Lottable12
			,   SKU.SKUGROUP
			,   SKU.itemclass
			,   WAVEDETAIL.Wavekey
			,   ISNULL(@c_RetVal,'') AS LOGO
	FROM LOADPLAN WITH (NOLOCK)
	JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
	JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.orderkey = ORDERS.OrderKey) 
    JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.orderkey = ORDERS.OrderKey)
	JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)  
	JOIN PICKDETAIL   WITH (NOLOCK) ON  (ORDERS.Orderkey = PICKDETAIL.Orderkey) AND (ORDERDETAIL.ORDERLINENUMBER = PICKDETAIL.ORDERLINENUMBER)
	JOIN REFKEYLOOKUP WITH (NOLOCK) ON (PICKDETAIL.PickDetailKey = REFKEYLOOKUP.PickDetailKey)  
	JOIN PICKHEADER WITH (NOLOCK) ON (REFKEYLOOKUP.PickSlipNo = PICKHEADER.PickHeaderkey)
											AND(LOADPLAN.LoadKey = PICKHEADER.ExternOrderkey) 
	JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey) 
									AND(PICKDETAIL.Sku = SKU.Sku) AND (ORDERDETAIL.SKU = SKU.SKU)
	JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
	JOIN LOTATTRIBUTE WITH (NOLOCK) on (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
	JOIN WAVEDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = WAVEDETAIL.Orderkey)
    LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'RPT_LP_POPUPSLIST_003'    
                                             AND CL1.Storerkey = ORDERS.StorerKey ) 
    LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCFG' AND CL2.Code = 'ShowZeroQty' AND CL2.Long = 'RPT_LP_POPUPSLIST_003'    
                                             AND CL2.Storerkey = ORDERS.StorerKey AND CL2.SHORT IN ('Y','N') ) 
    LEFT JOIN CODELKUP PG WITH (NOLOCK) ON (PG.LISTNAME = 'REPORTCOPY' AND PG.LONG = 'RPT_LP_POPUPSLIST_003' AND PG.STORERKEY = ORDERS.STORERKEY)
	WHERE loadplan.loadkey = @c_Loadkey --AND (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) > 0
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
			,	ORDERS.Notes
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
			,   LOTATTRIBUTE.Lottable06
			,   ISNULL(CL2.SHORT,'')   
			,   PG.Description
			,   PG.Code
			,   PG.Short
			,   CASE WHEN (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) = 0 THEN 'Parent' ELSE '' END
			,   ORDERS.OrderGroup
			,	LOTATTRIBUTE.Lottable08
			,	LOTATTRIBUTE.Lottable10
			,	LOTATTRIBUTE.Lottable12
			,   SKU.SKUGROUP
			,   SKU.itemclass
			,   WAVEDETAIL.Wavekey
   UNION ALL
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
			,	ORDERS.Notes
			,	STORER.Company
			,   PICKHEADER.PickHeaderKey
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
			,   CBM = SUM(PICKDETAIL.Qty * SKU.StdCube)
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
			,   shelflife        = SKU.Shelflife 
			,   Exp_date         = CASE WHEN ISNULL(SKU.Shelflife,0) = 0  THEN NULL ELSE LOTATTRIBUTE.Lottable04 + SKU.Shelflife END        
			,   ShowExpDate      = CL1.Short 
			,   LEXTLoadKey      = Loadplan.Externloadkey 
			,   LPriority        = Loadplan.Priority 
			,   LPuserdefDate01  = Loadplan.LPuserdefDate01
			,   Lottable06 = LOTATTRIBUTE.Lottable06
			,   AllowZeroQty = ISNULL(CL2.SHORT,'')
			,   PG.Description AS copyname
			,   PG.Code AS copycode
			,   PG.Short AS copyshowcolumn
			,   CASE WHEN (ORDERDETAIL.QtyPreAllocated + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) = 0 THEN 'Parent' ELSE '' END
			,   ORDERS.OrderGroup
			,	LOTATTRIBUTE.Lottable08
			,	LOTATTRIBUTE.Lottable10
			,	LOTATTRIBUTE.Lottable12
			,   SKU.SKUGROUP
			,   SKU.itemclass
			,   WAVEDETAIL.Wavekey
			,	ISNULL(@c_RetVal,'') AS Logo
	FROM LOADPLAN WITH (NOLOCK)
	JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
	JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.orderkey = ORDERS.OrderKey) 
    JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.orderkey = ORDERS.OrderKey)
	JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)  
	JOIN PICKDETAIL   WITH (NOLOCK) ON  (ORDERS.Orderkey = PICKDETAIL.Orderkey) AND (ORDERDETAIL.ORDERLINENUMBER = PICKDETAIL.ORDERLINENUMBER)  
	JOIN PICKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PICKHEADER.OrderKey)
											AND(LOADPLAN.LoadKey = PICKHEADER.ExternOrderkey) 
	JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey) 
									AND(PICKDETAIL.Sku = SKU.Sku) AND (ORDERDETAIL.SKU = SKU.SKU)
	JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
	JOIN LOTATTRIBUTE WITH (NOLOCK) on (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
	JOIN WAVEDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = WAVEDETAIL.Orderkey)

    LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'RPT_LP_POPUPSLIST_003'    
                                             AND CL1.Storerkey = ORDERS.StorerKey ) 
    LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCFG' AND CL2.Code = 'ShowZeroQty' AND CL2.Long = 'RPT_LP_POPUPSLIST_003'    
                                             AND CL2.Storerkey = ORDERS.StorerKey AND CL2.SHORT IN ('Y','N') ) 
    LEFT JOIN CODELKUP PG WITH (NOLOCK) ON (PG.LISTNAME = 'REPORTCOPY' AND PG.LONG = 'RPT_LP_POPUPSLIST_003' AND PG.STORERKEY = ORDERS.STORERKEY)
	WHERE loadplan.loadkey = @c_Loadkey
    GROUP BY LOADPLAN.Loadkey
			,  LOADPLAN.Facility
			,  LOADPLAN.Route
			,  LOADPLAN.CarrierKey
			,  LOADPLAN.TruckSize
			,  LOADPLAN.Driver
			,  ORDERS.Consigneekey
			,  ORDERS.C_Company
			,  ORDERS.C_Address1
			,  ORDERS.C_Address2
			,  ORDERS.C_Address3
			,  ORDERS.C_Address4
			,  ORDERS.C_City
			,  ORDERS.Externorderkey
			,  ORDERS.Notes
			,  STORER.Company
			,  PICKHEADER.PickHeaderKey
			,  PICKDETAIL.Storerkey
			,  PICKDETAIL.Sku 
			,  SKU.Descr
			,  PICKDETAIL.UOM
		    ,  PACK.PackUOM1
			,  PACK.CaseCnt
			,  PACK.PackUOM2
			,  PACK.InnerPack
			,  PACK.PackUOM3
			,  PACK.PackUOM4
			,  PACK.Pallet
			,  LOTATTRIBUTE.Lottable02
			,  LOTATTRIBUTE.Lottable04
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
			,  ORDERS.OrderGroup
			,  LOTATTRIBUTE.Lottable08
			,  LOTATTRIBUTE.Lottable10
			,  LOTATTRIBUTE.Lottable12
			,  SKU.SKUGROUP
			,  SKU.itemclass
			,  WAVEDETAIL.Wavekey
   SELECT * FROM #Temp_SortList20

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO