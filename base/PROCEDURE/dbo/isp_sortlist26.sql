SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Stored Proc: isp_sortlist26                                          */  
/* Creation Date: 12-MAR-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-16518  - PH_Huhtamaki_Loading_Guide_CR                  */  
/*        :                                                             */  
/* Called By: r_dw_sortlist26                                           */  
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
CREATE PROC [dbo].[isp_sortlist26] 
           @c_Loadkey         NVARCHAR(10)  
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
         , @c_RptByODUOM      NVARCHAR(10) = 'N'  
  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   WHILE @@TRANCOUNT > 0   
   BEGIN  
      COMMIT TRAN  
   END  
  
   --IF OBJECT_ID('tempdb..#TMP_SORTLIST26','u') IS NOT NULL  
   --BEGIN  
   --   DROP TABLE #TMP_SORTLIST26;  
   --END  
  
  
    SELECT  LOADPLAN.Loadkey
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
         ,  STORER.Company
         ,  PICKHEADER.PickHeaderKey
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.Sku 
         ,  SKU.Descr
         ,  UOM = CASE PICKDETAIL.UOM WHEN '1' THEN PACK.PACKUOM4
                                      WHEN '2' THEN PACK.PACKUOM1
                                      WHEN '3' THEN PACK.PACKUOM2
                                      WHEN '6' THEN PACK.PACKUOM3
                                      WHEN '7' THEN PACK.PACKUOM3
                  END
         ,  Qty = SUM(PICKDETAIL.QTY) 
         ,  CBM = SUM(PICKDETAIL.Qty * SKU.StdCube)
         ,  PACK.PackUOM1
         ,  PACK.CaseCnt
         ,  PACK.PackUOM2
         ,  PACK.InnerPack
         ,  PACK.PackUOM3
         ,  PACK.PackUOM4
         ,  PACK.Pallet
         ,  LOTATTRIBUTE.Lottable01
         ,  LOTATTRIBUTE.Lottable13
         ,  Prepared = CONVERT(char(10), SUSER_NAME())  
         ,  ReportType = ''
         ,  shelflife        = SKU.Shelflife 
         ,  Exp_date         = CASE WHEN ISNULL(SKU.Shelflife,0) = 0  THEN NULL ELSE LOTATTRIBUTE.Lottable04 + SKU.Shelflife END        
         ,  ShowExpDate      = CL1.Short 
         ,  LEXTLoadKey      = Loadplan.Externloadkey 
         ,  LPriority        = Loadplan.Priority 
         ,  LPuserdefDate01  = Loadplan.LPuserdefDate01
         ,  CL2.Description AS Copyname
         ,  CL2.Code AS Copycode
         ,  CL2.Short AS Copyshowcolumn
         ,  QtyCtn = SUM(PICKDETAIL.QTY) /nullif(PACK.CaseCnt,0)
   FROM LOADPLAN WITH (NOLOCK)
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
   JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.orderkey = ORDERS.OrderKey) 
   JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)  
   JOIN PICKDETAIL   WITH (NOLOCK) ON  (ORDERS.Orderkey = PICKDETAIL.Orderkey)
   JOIN REFKEYLOOKUP WITH (NOLOCK) ON (PICKDETAIL.PickDetailKey = REFKEYLOOKUP.PickDetailKey)  
   JOIN PICKHEADER WITH (NOLOCK) ON (REFKEYLOOKUP.PickSlipNo = PICKHEADER.PickHeaderkey)
                                 AND(LOADPLAN.LoadKey= PICKHEADER.ExternOrderkey) 
   JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey) 
                           AND(PICKDETAIL.Sku = SKU.Sku) 
   JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
   JOIN LOTATTRIBUTE WITH (NOLOCK) on (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) 
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'r_dw_sortlist26'    
                                             AND CL1.Storerkey = ORDERS.StorerKey ) 
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCOPY' AND CL2.Long = 'r_dw_sortlist26' AND CL2.Storerkey = ORDERS.StorerKey ) 
   WHERE loadplan.loadkey = @c_loadkey  
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
         ,  LOTATTRIBUTE.Lottable01
         ,  LOTATTRIBUTE.Lottable13
         ,  LOTATTRIBUTE.Lottable04
         ,  SKU.Shelflife                    
         ,  CL1.Short    
         ,  Loadplan.Externloadkey 
         ,  Loadplan.Priority 
         ,  Loadplan.LPuserdefDate01   
         ,  CL2.Description
         ,  CL2.Code 
         ,  CL2.Short                  
   ORDER BY PICKHEADER.PickHeaderKey
         ,  ORDERS.ExternOrderkey
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.Sku


  
QUIT_SP:     
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
END  


GO