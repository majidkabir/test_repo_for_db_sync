SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOrderProcPickGraph                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 10-Sep-2009  Shong   1.1   Add IDS Order's Status                    */
/************************************************************************/

CREATE PROC [dbo].[nspOrderProcPickGraph](
@OrderKeyStart          NVARCHAR(10),
@OrderKeyEnd            NVARCHAR(10),
@StorerKeyStart         NVARCHAR(15),
@StorerKeyEnd           NVARCHAR(15),
@OrderDateStart         datetime,
@OrderDateEnd           datetime,
@DeliveryDateStart      datetime,
@DeliveryDateEnd        datetime,
@TypeStart              NVARCHAR(10),
@TypeEnd                NVARCHAR(10),
@OrderGroupStart        NVARCHAR(20),
@OrderGroupEnd          NVARCHAR(20),
-- 			@InterModalVehicleStart NVARCHAR(30),
-- 			@InterModalVehicleEnd   NVARCHAR(30),
@ConsigneeKeyStart      NVARCHAR(15),
@ConsigneeKeyEnd        NVARCHAR(15),
@StatusStart            NVARCHAR(10),
@StatusEnd              NVARCHAR(10),
@ExternOrderKeyStart    NVARCHAR(20),
@ExternOrderKeyEnd      NVARCHAR(20),
@PriorityStart          NVARCHAR(20),
@PriorityEnd            NVARCHAR(10),
@FacilityStart			 NVARCHAR(5),
@FacilityEnd			 NVARCHAR(5)
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF


   SELECT CASE ORDERS.[Status]
                     WHEN '0' THEN '0-Normal'
                     WHEN '1' THEN '1-Partial'
                     WHEN '2' THEN '2-Fully'
                     WHEN '3' THEN '3-Picking'
                     WHEN '5' THEN '5-Picked'
                     WHEN '9' THEN '9-Shipped'
                     END, 
          SUM(CASE WHEN PICKDETAIL.UOM IN ('6','7') THEN PICKDETAIL.Qty 
                   WHEN PICKDETAIL.UOM = '1' THEN 1 
                   WHEN PICKDETAIL.UOM = '2' THEN PICKDETAIL.Qty / PACK.CaseCnt 
                   WHEN PICKDETAIL.UOM = '3' THEN PICKDETAIL.QTY / PACK.InnerPack
                   ELSE PICKDETAIL.Qty 
              END)
   FROM PICKDETAIL WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON ( PICKDETAIL.OrderKey = ORDERS.OrderKey ) 
   JOIN PACK WITH (NOLOCK) ON (PACK.PackKey = PickDetail.PackKey)
   WHERE PACK.CaseCnt > 0 AND 
     ORDERS.Status IN ('1','2','3','5') AND
   ( PICKDETAIL.OrderKey >= @OrderKeyStart ) AND
   ( PICKDETAIL.OrderKey <= @OrderKeyEnd ) AND
   ( PICKDETAIL.StorerKey >= @StorerKeyStart ) AND
   ( PICKDETAIL.StorerKey <= @StorerKeyEnd ) AND
   ( ORDERS.OrderDate >= @OrderDateStart ) AND
   ( ORDERS.OrderDate <= @OrderDateEnd ) AND
   ( ORDERS.DeliveryDate >= @DeliveryDateStart ) AND
   ( ORDERS.DeliveryDate <= @DeliveryDateEnd ) AND
   ( ORDERS.Type >= @TypeStart ) AND
   ( ORDERS.Type <= @TypeEnd ) AND
   ( ORDERS.OrderGroup >= @OrderGroupStart ) AND
   ( ORDERS.OrderGroup <= @OrderGroupEnd ) AND
   ( ORDERS.ConsigneeKey >= @ConsigneeKeyStart ) AND
   ( ORDERS.ConsigneeKey <= @ConsigneeKeyEnd ) AND
   ( ORDERS.Status >= @StatusStart ) AND
   ( ORDERS.Status <= @StatusEnd ) AND
   ( ORDERS.ExternOrderKey >= @ExternOrderKeyStart ) AND
   ( ORDERS.ExternOrderKey <= @ExternOrderKeyEnd ) AND
   ( ORDERS.Priority >= @PriorityStart ) AND
   ( ORDERS.Priority <= @PriorityEnd ) AND
   ( ORDERS.Facility >= @FacilityStart ) AND
   ( ORDERS.Facility <= @FacilityEnd ) 
   GROUP BY ORDERS.Status 
   UNION 
   SELECT 'All', 
          SUM(CASE WHEN PICKDETAIL.UOM IN ('6','7') THEN PICKDETAIL.Qty 
                   WHEN PICKDETAIL.UOM = '1' THEN 1 
                   WHEN PICKDETAIL.UOM = '2' THEN PICKDETAIL.Qty / PACK.CaseCnt 
                   WHEN PICKDETAIL.UOM = '3' THEN PICKDETAIL.QTY / PACK.InnerPack
                   ELSE PICKDETAIL.Qty 
              END)
   FROM PICKDETAIL WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON ( PICKDETAIL.OrderKey = ORDERS.OrderKey ) 
   JOIN PACK WITH (NOLOCK) ON (PACK.PackKey = PickDetail.PackKey)
   WHERE PACK.CaseCnt > 0 AND 
     ORDERS.Status IN ('1','2','3','5') AND
   ( PICKDETAIL.OrderKey >= @OrderKeyStart ) AND
   ( PICKDETAIL.OrderKey <= @OrderKeyEnd ) AND
   ( PICKDETAIL.StorerKey >= @StorerKeyStart ) AND
   ( PICKDETAIL.StorerKey <= @StorerKeyEnd ) AND
   ( ORDERS.OrderDate >= @OrderDateStart ) AND
   ( ORDERS.OrderDate <= @OrderDateEnd ) AND
   ( ORDERS.DeliveryDate >= @DeliveryDateStart ) AND
   ( ORDERS.DeliveryDate <= @DeliveryDateEnd ) AND
   ( ORDERS.Type >= @TypeStart ) AND
   ( ORDERS.Type <= @TypeEnd ) AND
   ( ORDERS.OrderGroup >= @OrderGroupStart ) AND
   ( ORDERS.OrderGroup <= @OrderGroupEnd ) AND
   ( ORDERS.ConsigneeKey >= @ConsigneeKeyStart ) AND
   ( ORDERS.ConsigneeKey <= @ConsigneeKeyEnd ) AND
   ( ORDERS.Status >= @StatusStart ) AND
   ( ORDERS.Status <= @StatusEnd ) AND
   ( ORDERS.ExternOrderKey >= @ExternOrderKeyStart ) AND
   ( ORDERS.ExternOrderKey <= @ExternOrderKeyEnd ) AND
   ( ORDERS.Priority >= @PriorityStart ) AND
   ( ORDERS.Priority <= @PriorityEnd ) AND
   ( ORDERS.Facility >= @FacilityStart ) AND
   ( ORDERS.Facility <= @FacilityEnd ) 


END


GO