SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: nspConsoPickSlipNormal09                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Consolidated Normal Pickslip                                */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 16-June-2005 Vicky         SOS#36961 - Change Pickslip format        */
/* 22-Feb-2010  KC            SOS#161698 - Change Pickslip info (KC01)  */
/* 16-Dec-2018  TLTING01 1.1  missing nolock                            */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickSlipNormal09]
@c_LoadKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @d_ExprDate DateTime
   SELECT  @d_ExprDate = NULL
   SELECT CAST(PICKHEADER.PickHeaderKey as NVARCHAR(10)) as PickSlipNo, 
          LoadPlan.LoadKey,          
          ORDERS.OrderKey,
          ORDERS.ConsigneeKey, 
          ORDERS.C_Company,
          ORDERS.C_Address1, 
          ORDERS.C_Address2, 
          ORDERS.C_Address3, 
/*
          ORDERS.C_Zip,
          ORDERS.Route, 
          '' as RouteDesc,  
          LOADPLAN.TrfRoom, 
          Remarks=convert(char(60), ORDERS.Notes),           
          Remarks2=convert(char(60), ORDERS.Notes2), 
          PICKDETAIL.LOC, 
*/ -- (KC01)
          PICKDETAIL.SKU, 
          SKU.DESCR, 
          SUM(PickDetail.Qty) as QTY, 
          PACK.CaseCnt,
/*        2 as UOM, 
          1 as UOMQty, 
*/ -- (KC01)
          CAST(PICKHEADER.PickType as NVARCHAR(1)) as PrintFlag, 
/*
          PICKHEADER.Zone, 
          0 as PageGroup, 
          0 as RowNo, 
          PickDetail.Lot, 
          LOADPLAN.Carrierkey, 
          LOADPLAN.Truck_Type, 
*/ -- (KC01)
          LOTATTRIBUTE.Lottable02, 
          convert(varchar(10),LOTATTRIBUTE.LOTTABLE04,120) as lottable04,  --(KC01)
--          ORDERS.LabelPrice,   --(KC010
          ORDERS.ExternOrderKey, 
/*
          LoadPlan.Driver, -- Driver Name
          CAST(LoadPlan.Load_Userdef1 as NVARCHAR(60)), -- Driver Mobile Phone#
          LoadPlan.TruckSize, 
          Loadplan.lpuserdefdate01,  -- ETA 
          Loadplan.Delivery_Zone, 
*/ -- (KC01)
          Loadplan.ExternLoadKey,
          Pickdetail.Loc
/*
          SKU.SUSR3, 
	  LOC.LogicalLocation,
          LOADPLAN.Adddate -- SOS#36961   
*/ -- (KC01)
   FROM LoadPlan (NOLOCK) 
   JOIN LoadPlanDetail (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey) 
   JOIN PICKHEADER (NOLOCK) ON (PICKHEADER.ExternOrderKey = LoadPlan.LoadKey AND PICKHEADER.Zone = '7')
   JOIN ORDERS (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey) 
   JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey AND LoadPlanDetail.Loadkey = ORDERDETAIL.Loadkey)
   JOIN SKU (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.Storerkey AND SKU.Sku = ORDERDETAIL.Sku)
   JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PACKKey)  -- (KC01)
   JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND
                   PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
   LEFT OUTER JOIN LOTATTRIBUTE (NOLOCK) ON (LOTATTRIBUTE.LOT = PICKDETAIL.LOT) --tlting01
   JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)
   WHERE LoadPlan.LoadKey = @c_LoadKey
   --AND   (ORDERDETAIL.Lottable04 > '19000101' OR ORDERDETAIL.Lottable04 IS NOT NULL) --(KC01)
   GROUP BY CAST(PICKHEADER.PickHeaderKey as NVARCHAR(10)), 
          LoadPlan.LoadKey,          
          ORDERS.OrderKey,
          ORDERS.ConsigneeKey, 
          ORDERS.C_Company,
          ORDERS.C_Address1, 
          ORDERS.C_Address2, 
          ORDERS.C_Address3, 
          PICKDETAIL.SKU, 
          SKU.DESCR, 
          PACK.CaseCnt,
          CAST(PICKHEADER.PickType as NVARCHAR(1)), 
          LOTATTRIBUTE.Lottable02, 
          convert(varchar(10),LOTATTRIBUTE.LOTTABLE04,120),
          ORDERS.ExternOrderKey, 
          Loadplan.ExternLoadKey,
          PICKDETAIL.LOC

END -- Procedure

GO