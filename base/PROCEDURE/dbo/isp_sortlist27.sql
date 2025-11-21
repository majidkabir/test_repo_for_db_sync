SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Stored Proc: isp_sortlist27                                          */  
/* Creation Date: 16-MAR-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:WMS-16425-PH_Mondelez_RCM_LoadingGuide_UOMColumn_Modification*/  
/*        :                                                             */  
/* Called By: r_dw_sortlist27                                           */  
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
CREATE PROC [dbo].[isp_sortlist27] 
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
             , OD.UOM  
             , Qty = (od.QTYAllocated+od.ShippedQty) /CASE WHEN od.uom = pack.packuom1 then pack.casecnt
                                                                                             WHEN od.uom = pack.packuom2 then pack.innerpack
                                                                                             WHEN od.uom = pack.packuom3 then pack.qty
                                                                                             WHEN od.uom = pack.packuom4 then pack.pallet
                                                                                     ELSE 1 END
         ,  CBM = SUM(PICKDETAIL.Qty * SKU.StdCube)
         ,  PACK.PackUOM1
         ,  PACK.CaseCnt
         ,  PACK.PackUOM2
         ,  PACK.InnerPack
         ,  CASE WHEN PACK.PackUOM1 = PACK.PackUOM3 THEN 'EA' ELSE PACK.PackUOM3 END
         ,  PACK.PackUOM4
         ,  PACK.Pallet
         ,  LOTATTRIBUTE.Lottable02
         ,  LOTATTRIBUTE.Lottable04
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
   FROM LOADPLAN WITH (NOLOCK)
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
   JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.orderkey = ORDERS.OrderKey) 
   JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)  
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = ORDERS.Orderkey 
   JOIN PICKDETAIL   WITH (NOLOCK) ON  (OD.Orderkey = PICKDETAIL.Orderkey AND PICKDETAIL.sku = OD.sku)
   JOIN REFKEYLOOKUP WITH (NOLOCK) ON (PICKDETAIL.PickDetailKey = REFKEYLOOKUP.PickDetailKey)  
   JOIN PICKHEADER WITH (NOLOCK) ON (REFKEYLOOKUP.PickSlipNo = PICKHEADER.PickHeaderkey)
                                 AND(LOADPLAN.LoadKey= PICKHEADER.ExternOrderkey) 
   JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey) 
                           AND(PICKDETAIL.Sku = SKU.Sku) 
   JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
   JOIN LOTATTRIBUTE WITH (NOLOCK) on (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) 
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'r_dw_sortlist27'    
                                             AND CL1.Storerkey = ORDERS.StorerKey ) 
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCOPY' AND CL2.Long = 'r_dw_sortlist27' AND CL2.Storerkey = ORDERS.StorerKey ) 
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
         ,  OD.UOM
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
         ,  CL2.Description
         ,  CL2.Code 
         ,  CL2.Short       
         ,  pack.qty      
         , (od.QTYAllocated+od.ShippedQty)     
  ORDER BY PICKHEADER.PickHeaderKey  
   , ORDERS.ExternOrderkey  
   , PICKDETAIL.Storerkey  
   , PICKDETAIL.Sku  



  
QUIT_SP:     
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
END  

GO