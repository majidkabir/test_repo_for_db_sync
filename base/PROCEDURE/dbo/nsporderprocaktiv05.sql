SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOrderProcAktiv05                                */
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
/************************************************************************/

CREATE PROC [dbo].[nspOrderProcAktiv05] (
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

   DECLARE  @PicksAllocated     int,
   @PicksProcess       int,
   @PicksShipped       int,
   @PicksPicked        int
   Create TABLE #Data (
   c_Category    NVARCHAR(8)  NULL,
   i_Value       int      NULL,
   c_Series      NVARCHAR(30) NULL)
   INSERT into #Data
   SELECT Convert(char(8), ORDERS.OrderDate, 1),
   count(DISTINCT ORDERS.OrderKey ),
   'Number of ORDERs Received'
   FROM ORDERS (NOLOCK), PICKDETAIL (NOLOCK)
   WHERE ( ORDERS.OrderKey = PICKDETAIL.OrderKey )  AND
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
   -- 		( ORDERS.IntermodalVehicle >= @InterModalVehicleStart ) AND
   -- 		( ORDERS.IntermodalVehicle <= @InterModalVehicleEnd ) AND
   ( ORDERS.ConsigneeKey >= @ConsigneeKeyStart ) AND
   ( ORDERS.ConsigneeKey <= @ConsigneeKeyEnd ) AND
   ( PICKDETAIL.Status >= @StatusStart ) AND
   ( PICKDETAIL.Status <= @StatusEnd ) AND
   ( ORDERS.ExternOrderKey >= @ExternOrderKeyStart ) AND
   ( ORDERS.ExternOrderKey <= @ExternOrderKeyEnd ) AND
   ( ORDERS.Priority >= @PriorityStart ) AND
   ( ORDERS.Priority <= @PriorityEnd ) AND
   ( ORDERS.Facility >= @FacilityStart ) AND
   ( ORDERS.Facility <= @FacilityEnd )
   GROUP BY convert(char(8), ORDERS.OrderDate, 1 )
   UNION
   SELECT convert(char(8), ORDERS.OrderDate, 1 ),
   count(DISTINCT PICKDETAIL.CaseID),
   'Number of CASEs Processed'
   FROM ORDERS (NOLOCK), PICKDETAIL (NOLOCK)
   WHERE ( ORDERS.OrderKey = PICKDETAIL.OrderKey )  AND
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
   -- 		( ORDERS.IntermodalVehicle >= @InterModalVehicleStart ) AND
   -- 		( ORDERS.IntermodalVehicle <= @InterModalVehicleEnd ) AND
   ( ORDERS.ConsigneeKey >= @ConsigneeKeyStart ) AND
   ( ORDERS.ConsigneeKey <= @ConsigneeKeyEnd ) AND
   ( PICKDETAIL.Status >= @StatusStart ) AND
   ( PICKDETAIL.Status <= @StatusEnd ) AND
   ( ORDERS.ExternOrderKey >= @ExternOrderKeyStart ) AND
   ( ORDERS.ExternOrderKey <= @ExternOrderKeyEnd ) AND
   ( ORDERS.Priority >= @PriorityStart ) AND
   ( ORDERS.Priority <= @PriorityEnd ) AND
   ( ORDERS.Facility >= @FacilityStart ) AND
   ( ORDERS.Facility <= @FacilityEnd )
   GROUP BY convert(char(8), ORDERS.OrderDate, 1 )
   UNION
   SELECT Convert(char(8), ORDERS.OrderDate, 1),
   count(DISTINCT PICKDETAIL.PickDetailKey ),
   'Number of PICKs Processed'
   FROM ORDERS (NOLOCK), PICKDETAIL (NOLOCK)
   WHERE ( ORDERS.OrderKey = PICKDETAIL.OrderKey )  AND
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
   -- 		( ORDERS.IntermodalVehicle >= @InterModalVehicleStart ) AND
   -- 		( ORDERS.IntermodalVehicle <= @InterModalVehicleEnd ) AND
   ( ORDERS.ConsigneeKey >= @ConsigneeKeyStart ) AND
   ( ORDERS.ConsigneeKey <= @ConsigneeKeyEnd ) AND
   ( PICKDETAIL.Status >= @StatusStart ) AND
   ( PICKDETAIL.Status <= @StatusEnd ) AND
   ( ORDERS.ExternOrderKey >= @ExternOrderKeyStart ) AND
   ( ORDERS.ExternOrderKey <= @ExternOrderKeyEnd ) AND
   ( ORDERS.Priority >= @PriorityStart ) AND
   ( ORDERS.Priority <= @PriorityEnd ) AND
   ( ORDERS.Facility >= @FacilityStart ) AND
   ( ORDERS.Facility <= @FacilityEnd )
   GROUP BY convert(char(8), ORDERS.OrderDate, 1 )
   SELECT category = c_Category,
   value = i_Value,
   series = c_Series
   FROM #Data
END

GO