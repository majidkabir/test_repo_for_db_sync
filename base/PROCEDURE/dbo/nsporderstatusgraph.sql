SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOrderStatusGraph                                */
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

CREATE PROC [dbo].[nspOrderStatusGraph](
@OrderKeyStart      	 NVARCHAR(10),
@OrderKeyEnd            NVARCHAR(10),
@StorerKeyStart         NVARCHAR(15),
@StorerKeyEnd           NVARCHAR(15),
@OrderDateStart         datetime,
@OrderDateEnd           datetime,
@DeliveryDateStart      datetime,
@DeliveryDateEnd        datetime,
@TypeStart              NVARCHAR(10),
@TypeEnd            	 NVARCHAR(10),
@OrderGroupStart        NVARCHAR(20),
@OrderGroupEnd      	 NVARCHAR(20),
-- 			@InterModalVehicleStart NVARCHAR(30),
-- 			@InterModalVehicleEnd   NVARCHAR(30),
@ConsigneeKeyStart      NVARCHAR(15),
@ConsigneeKeyEnd        NVARCHAR(15),
@StatusStart            NVARCHAR(10),
@StatusEnd              NVARCHAR(10),
@ExternOrderKeyStart    NVARCHAR(20),
@ExternOrderKeyEnd      NVARCHAR(20),
@PriorityStart      	 NVARCHAR(10),
@PriorityEnd            NVARCHAR(10),
@FacilityStart			 NVARCHAR(5),
@FacilityEnd			 NVARCHAR(5)
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT CASE ORDERS.Status
                     WHEN '0' THEN '0-Normal'
                     WHEN '1' THEN '1-Partial'
                     WHEN '2' THEN '2-Fully'
                     WHEN '3' THEN '3-Picking'
                     WHEN '5' THEN '5-Picked'
                     WHEN '9' THEN '9-Shipped'
                     END, 
          FLOOR(SUM(CASE WHEN ORDERS.Status = '0' THEN ORDERDETAIL.OpenQty 
                         WHEN ORDERS.Status = '1' THEN ORDERDETAIL.OpenQty 
                         WHEN ORDERS.Status = '2' THEN ORDERDETAIL.QtyAllocated
                         WHEN ORDERS.Status = '3' THEN ORDERDETAIL.QtyAllocated + QtyPicked 
                         WHEN ORDERS.Status = '5' THEN ORDERDETAIL.QtyPicked 
                         WHEN ORDERS.Status = '9' THEN ORDERDETAIL.QtyAllocated + QtyPicked + ShippedQty 
                    END) 
                        ) As Qty
   FROM ORDERDETAIL WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey ) 
   WHERE ( ORDERDETAIL.OrderKey >= @OrderKeyStart ) AND
   ( ORDERDETAIL.OrderKey <= @OrderKeyEnd ) AND
   ( ORDERDETAIL.StorerKey >= @StorerKeyStart ) AND
   ( ORDERDETAIL.StorerKey <= @StorerKeyEnd ) AND
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

END


GO