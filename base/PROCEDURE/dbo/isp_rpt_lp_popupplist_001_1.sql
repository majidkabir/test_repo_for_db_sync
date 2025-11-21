SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_LP_POPUPPLIST_001_1                             */
/* Creation Date: 05-05-2022                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Amal                                                     */
/*                                                                      */
/* Purpose: WMS-19507 - Migrate WMS report to Logi Report               */
/*        : r_dw_sortlist23 (PH)                                        */
/*          WMS-21880 - Loading Guide Enhancement (Add Columns)         */
/*                                                                      */
/* Called By:  RPT_LP_POPUPPLIST_001_1                                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 05-May-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 10-Mar-2023  WZPang   1.1  Add Columns                               */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_LP_POPUPPLIST_001_1]
           @c_Loadkey         NVARCHAR(10)
         , @c_ReportType      NVARCHAR(50)
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
        ,   Lottable04        DATETIME       NULL             
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
   AND CL.Long = 'RPT_LP_POPUPPLIST_001_1' 
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
      LEFT JOIN LOTATTRIBUTE LA WITH (NOLOCK)    
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
      LEFT JOIN LOTATTRIBUTE LA WITH (NOLOCK)    
         ON PD.Lot = LA.Lot
      WHERE LP.Loadkey = @c_Loadkey
   END

QUIT_SP:  

   SELECT   LOADPLAN.Loadkey
         ,  LOADPLAN.Facility
         ,  [Route]     = ISNULL(LOADPLAN.[Route],'')
         ,  CarrierKey  = ISNULL(LOADPLAN.CarrierKey,'')
         ,  TruckSize   = ISNULL(LOADPLAN.TruckSize,'')
         ,  Driver      = ISNULL(LOADPLAN.Driver,'')
         ,  Consigneekey= ISNULL(ORDERS.Consigneekey,'')
         ,  C_Company   = ISNULL(ORDERS.C_Company,'')
         ,  C_Address1  = ISNULL(ORDERS.C_Address1,'')
         ,  C_Address2  = ISNULL(ORDERS.C_Address2,'')
         ,  C_Address3  = ISNULL(ORDERS.C_Address3,'')
         ,  C_Address4  = ISNULL(ORDERS.C_Address4,'')
         ,  C_City      = ISNULL(ORDERS.C_City,'')
         --,  Externorderkey = ISNULL(ORDERS.Externorderkey,'')
         ,  Company     = ISNULL(STORER.Company,'')
         ,  PICKHEADER.PickHeaderKey
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.Sku 
         ,  Descr       = ISNULL(SKU.Descr,'')
         ,  UOM  = CASE WHEN @c_RptByODUOM = 'Y' THEN T.UOM
                        WHEN T.UOM = '1' THEN PACK.PACKUOM4
                        WHEN T.UOM = '2' THEN PACK.PACKUOM1
                        WHEN T.UOM = '3' THEN PACK.PACKUOM2
                        WHEN T.UOM = '6' THEN PACK.PACKUOM3
                        WHEN T.UOM = '7' THEN PACK.PACKUOM3
                        ELSE ''
                  END
         ,  Qty = ( SELECT TOP 1 ISNULL(PD.QTY,0) FROM #TMP_RDTDATA Tem  (NOLOCK)    
                    JOIN LOADPLAN WITH (NOLOCK) ON (Tem.Loadkey = LOADPLAN.Loadkey)    
                    JOIN ORDERS WITH (NOLOCK) ON (Tem.orderkey = ORDERS.OrderKey)     
                    JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)     
                    JOIN PICKDETAIL  PD WITH (NOLOCK) ON  (ORDERS.Orderkey = PD.Orderkey)    
                                                    AND (PD.PickDetailkey = Tem.PickDetailKey)                                      
                    JOIN REFKEYLOOKUP WITH (NOLOCK) ON  (PD.PickDetailKey = REFKEYLOOKUP.PickDetailKey)  
                    LEFT JOIN CODELKUP CLk3 (NOLOCK) ON CLk3.LISTNAME = 'ReportCopy' AND CLk3.Long = 'RPT_LP_POPUPPLIST_001.cls' AND CLk3.Storerkey = ORDERS.Storerkey  AND CLk3.Description = @c_ReportType  
                    WHERE PD.SKU = PICKDETAIL.Sku )  
         --,  QTY  = CASE WHEN T.UOM = PACK.PackUOM1 THEN SUM(PICKDETAIL.Qty) / PACK.CaseCnt
         --               WHEN T.UOM = PACK.PackUOM2 THEN SUM(PICKDETAIL.Qty) / PACK.InnerPack
         --               WHEN T.UOM = PACK.PackUOM4 THEN SUM(PICKDETAIL.Qty) / PACK.CaseCnt
         --               ELSE SUM(PICKDETAIL.Qty)
         --          END
         ,  CBM = ( SELECT TOP 1 ISNULL(PD.QTY,0) * ISNULL(SKU.StdCube,0.00) FROM #TMP_RDTDATA T  (NOLOCK)    
                    JOIN LOADPLAN WITH (NOLOCK) ON (T.Loadkey = LOADPLAN.Loadkey)    
                    JOIN ORDERS WITH (NOLOCK) ON (T.orderkey = ORDERS.OrderKey)     
                    JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey)     
                    JOIN PICKDETAIL  PD WITH (NOLOCK) ON  (ORDERS.Orderkey = PD.Orderkey)    
                                                    AND (PD.PickDetailkey = T.PickDetailKey)                                      
                    JOIN REFKEYLOOKUP WITH (NOLOCK) ON  (PD.PickDetailKey = REFKEYLOOKUP.PickDetailKey)  
                    JOIN SKU WITH (NOLOCK)  ON (PICKDETAIL.StorerKey = SKU.StorerKey)     
                           AND(PICKDETAIL.Sku = SKU.Sku)     
                    LEFT JOIN CODELKUP CLk3 (NOLOCK) ON CLk3.LISTNAME = 'ReportCopy' AND CLk3.Long = 'RPT_LP_POPUPPLIST_001.cls' AND CLk3.Storerkey = ORDERS.Storerkey  AND CLk3.Description = @c_ReportType   
                    WHERE PD.SKU = PICKDETAIL.Sku )   
         --,  CBM = ISNULL(SUM(PICKDETAIL.Qty * SKU.StdCube),0.00)
         ,  PACK.PackUOM1
         ,  PACK.CaseCnt
         ,  PACK.PackUOM2
         ,  PACK.InnerPack
         ,  PACK.PackUOM3
         ,  PACK.PackUOM4
         ,  PACK.Pallet
         ,  T.Lottable02  
         ,  T.Lottable04  
         ,  Prepared    = CONVERT(char(10), SUSER_NAME())  
         ,  ReportType  = CAST(@c_reporttype as char(3)) 
         ,  shelflife   = ISNULL(SKU.Shelflife,0) 
         ,  Exp_date    = CASE WHEN ISNULL(SKU.Shelflife,0) = 0 THEN NULL 
                               WHEN T.Lottable04 IS NULL THEN NULL 
                               ELSE T.Lottable04 + ISNULL(SKU.Shelflife,0) END        
         ,  ShowExpDate = ISNULL(CL1.Short,'') 
         ,  LEXTLoadKey = ISNULL(Loadplan.Externloadkey,'') 
         ,  LPriority   = ISNULL(Loadplan.[Priority],'') 
         ,  LPuserdefDate01= CASE WHEN CONVERT(NVARCHAR(8), Loadplan.LPuserdefDate01, 112) = '19000101' THEN NULL ELSE Loadplan.LPuserdefDate01 END
         --,  LOADPLAN.BookingNo   
         ,  ShowBookingNo = ISNULL(CL2.Short,'')
         ,  ORDERS.Door                                         --(WZ01)
         ,  TMS_SHIPMENT.BookingNo  AS TMS_Shipment_BookingNo   --(WZ01)
         --,  PalletID = CASE WHEN ISNULL(PICKDETAIL.ID,'') THEN PICKDETAIL.DropID
         --                   ELSE CASE WHEN ISNULL(PICKDETAIL.DropID,'') OR PICKDETAIL.DropID ='' THEN '' END
         ,  PAlletID = CASE WHEN ISNULL(PICKDETAIL.ID,'') <> '' THEN PICKDETAIL.ID ELSE CASE WHEN ISNULL(PICKDETAIL.DropID,'') <> '' THEN PICKDETAIL.DropID ELSE '' END  END
         ,  @c_ReportType AS Description
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
   LEFT JOIN TMS_SHIPMENT WITH (NOLOCK) ON (LOADPLAN.ExternLoadkey = TMS_SHIPMENT.ShipmentGID)
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG' AND CL1.Code = 'SHOWEXPDATE' AND CL1.Long = 'RPT_LP_POPUPPLIST_001_1'    
                                        AND CL1.Storerkey = ORDERS.StorerKey ) 
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCFG' AND CL2.Code = 'SHOWBOOKINGNO' AND CL2.Long = 'RPT_LP_POPUPPLIST_001_1'    
                                        AND CL2.Storerkey = ORDERS.StorerKey )
   --LEFT JOIN CODELKUP CL3 (NOLOCK) ON CL3.LISTNAME = 'ReportCopy' AND CL3.Long = 'RPT_LP_POPUPPLIST_001.cls' AND CL3.Storerkey = ORDERS.Storerkey                                 
   WHERE loadplan.loadkey = @c_Loadkey  
   GROUP BY LOADPLAN.Loadkey
         ,  LOADPLAN.Facility
         ,  ISNULL(LOADPLAN.[Route],'')
         ,  ISNULL(LOADPLAN.CarrierKey,'')
         ,  ISNULL(LOADPLAN.TruckSize,'')
         ,  ISNULL(LOADPLAN.Driver,'')
         ,  ISNULL(ORDERS.Consigneekey,'')
         ,  ISNULL(ORDERS.C_Company,'')
         ,  ISNULL(ORDERS.C_Address1,'')
         ,  ISNULL(ORDERS.C_Address2,'')
         ,  ISNULL(ORDERS.C_Address3,'')
         ,  ISNULL(ORDERS.C_Address4,'')
         ,  ISNULL(ORDERS.C_City,'')
         --,  ISNULL(ORDERS.Externorderkey,'')
         ,  ISNULL(STORER.Company,'')
         ,  PICKHEADER.PickHeaderKey
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.Sku 
         ,  ISNULL(SKU.Descr,'')
         ,  T.UOM
         ,  PACK.PackUOM1
         ,  PACK.CaseCnt
         ,  PACK.PackUOM2
         ,  PACK.InnerPack
         ,  PACK.PackUOM3
         ,  PACK.PackUOM4
         ,  PACK.Pallet
         ,  T.Lottable02 
         ,  T.Lottable04  
         ,  ISNULL(SKU.Shelflife,0)                
         ,  ISNULL(CL1.Short,'')   
         ,  ISNULL(Loadplan.Externloadkey,'') 
         ,  ISNULL(Loadplan.[Priority],'') 
         ,  CASE WHEN CONVERT(NVARCHAR(8), Loadplan.LPuserdefDate01, 112) = '19000101' THEN NULL ELSE Loadplan.LPuserdefDate01 END 
         ,  LOADPLAN.BookingNo   
         ,  ISNULL(CL2.Short,'') 
         ,  ORDERS.Door                --(WZ01)
         ,  TMS_SHIPMENT.BookingNo     --(WZ01)
         ,  PICKDETAIL.ID
         ,  PICKDETAIL.DropID
        -- ,  PICKDETAIL.Qty
       --  ,  CL3.Description
   ORDER BY PICKHEADER.PickHeaderKey
         --,  ISNULL(ORDERS.Externorderkey,'')
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.Sku
         
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO