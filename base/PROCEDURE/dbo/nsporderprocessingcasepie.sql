SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOrderProcessingCasePie                          */
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


/*******************************************************************
* Modification History:
*
* 06/11/2002 Leo Ng  Program rewrite for IDS version 5
* *****************************************************************/

CREATE PROC [dbo].[nspOrderProcessingCasePie](
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

   Create TABLE #PICKS (
   Status  NVARCHAR(30) NULL, 
   Qty     int )

-- ISNULL(CASE WHEN ORDERS.Status = '2' THEN FLOOR(SUM(PickDetail.Qty) / PACK.CASECNT) END,0) As AllocatedQty, 
-- ISNULL(CASE WHEN ORDERS.Status = '3' THEN FLOOR(SUM(PickDetail.Qty) / PACK.CASECNT) END,0) As PIPQty, 
-- ISNULL(CASE WHEN ORDERS.Status = '5' THEN FLOOR(SUM(PickDetail.Qty) / PACK.CASECNT) END,0) As PickedQty,
-- ISNULL(CASE WHEN ORDERS.Status = '9' THEN FLOOR(SUM(PickDetail.Qty) / PACK.CASECNT) END,0) As ShippedQty 


   INSERT into #PICKS (Status, Qty)
   SELECT ORDERS.Status, FLOOR(SUM(PickDetail.Qty) / PACK.CASECNT) As Qty
   FROM PICKDETAIL WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON ( PICKDETAIL.OrderKey = ORDERS.OrderKey ) 
   JOIN PACK WITH (NOLOCK) ON (PACK.PackKey = PickDetail.PackKey)
   WHERE PACK.CaseCnt > 0 AND 
     ORDERS.Status IN ('2','3','5','9') AND
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
   GROUP BY ORDERS.Status, PACK.CASECNT

   INSERT into #PICKS (Status, Qty)
   SELECT ORDERS.Status, 
          FLOOR(SUM(CASE WHEN ORDERS.Status = '0' THEN ORDERDETAIL.OpenQty 
                         WHEN ORDERS.Status = '1' THEN ORDERDETAIL.OpenQty END) / PACK.CASECNT) As Qty
   FROM ORDERDETAIL WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey ) 
   JOIN PACK WITH (NOLOCK) ON (PACK.PackKey = ORDERDETAIL.PackKey)
   WHERE PACK.CaseCnt > 0 AND 
     ORDERS.Status IN ('0','1') AND
   ( ORDERDETAIL.OrderKey >= @OrderKeyStart ) AND
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
   GROUP BY ORDERS.Status, PACK.CASECNT

   SELECT category = CASE [Status]
                     WHEN '0' THEN '0-Normal'
                     WHEN '1' THEN '1-Partial'
                     WHEN '2' THEN '2-Fully'
                     WHEN '3' THEN '3-Picking'
                     WHEN '5' THEN '5-Picked'
                     WHEN '9' THEN '9-Shipped'
                     END,
         SUM(Qty)
   FROM #PICKS 
   GROUP BY [Status]


END


GO