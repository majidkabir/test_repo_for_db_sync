SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nspConsoPickSlipNormal08                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version:                                                        */
/*                                                                      */
/* Version:                                                             */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 16-Dec-2018  TLTING01 1.1  missing nolock                            */
/************************************************************************/



CREATE PROC [dbo].[nspConsoPickSlipNormal08]
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
          ORDERS.C_Zip,
          ORDERS.Route, 
          '' as RouteDesc,  
          LOADPLAN.TrfRoom, 
          Remarks=convert(NVARCHAR(60), ORDERS.Notes),           
          Remarks2=convert(NVARCHAR(60), ORDERS.Notes2), 
          PICKDETAIL.LOC, 
          PICKDETAIL.SKU, 
          SKU.DESCR, 
          PickDetail.Qty, 
          2 as UOM, 
          1 as UOMQty, 
          '' as PrintFlag, 
          PICKHEADER.Zone, 
          0 as PageGroup, 
          0 as RowNo, 
          PickDetail.Lot, 
          LOADPLAN.Carrierkey, 
          LOADPLAN.Truck_Type, 
          LOTATTRIBUTE.Lottable02, 
          LOTATTRIBUTE.Lottable04, 
          ORDERS.LabelPrice,
          ORDERS.ExternOrderKey, 
          LoadPlan.Driver, -- Driver Name
          CAST(LoadPlan.Load_Userdef1 as NVARCHAR(60)), -- Driver Mobile Phone#
          LoadPlan.TruckSize, 
          Loadplan.lpuserdefdate01  -- ETA 
   FROM LoadPlan (NOLOCK) 
   JOIN LoadPlanDetail (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey) 
   JOIN PICKHEADER (NOLOCK) ON (PICKHEADER.ExternOrderKey = LoadPlan.LoadKey AND PICKHEADER.Zone = '7')
   JOIN ORDERS (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey) 
   JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey AND LoadPlanDetail.Loadkey = ORDERDETAIL.Loadkey)
   JOIN SKU (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.Storerkey AND SKU.Sku = ORDERDETAIL.Sku)
   JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND
                   PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
   LEFT OUTER JOIN LOTATTRIBUTE (NOLOCK) ON (LOTATTRIBUTE.LOT = PICKDETAIL.LOT) --tlting01
   JOIN (SELECT DISTINCT ORDERKEY FROM ORDERDETAIL (NOLOCK) WHERE LoadKey = @c_LoadKey AND
           (Lottable04 > '19000101' AND Lottable04 IS NOT NULL) )  as NonCodeDate 
         ON (NonCodeDate.ORDERKEY = ORDERS.OrderKey) 
   WHERE LoadPlan.LoadKey = @c_LoadKey

END -- Procedure


GO