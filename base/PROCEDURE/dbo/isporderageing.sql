SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispOrderAgeing                                     */
/* Creation Date: 12-Nov-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */  
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[ispOrderAgeing](
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
@ExternOrderKeyStart    NVARCHAR(50),   --tlting_ext
@ExternOrderKeyEnd      NVARCHAR(50),   --tlting_ext
@PriorityStart          NVARCHAR(20),
@PriorityEnd            NVARCHAR(10),
@FacilityStart			 NVARCHAR(5),
@FacilityEnd			 NVARCHAR(5)

  ) AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   CREATE TABLE #Result (
   	 WeekRange   NVARCHAR(20)
   	,StatusDesc  NVARCHAR(30)
   	,NoOfOrders  INT
   	,OrderLines  INT
   	,TotUnits    INT
   	)
   
   INSERT INTO #Result (WeekRange, StatusDesc, NoOfOrders, OrderLines, TotUnits)
   SELECT CASE WHEN DateDiff(week, ORDERS.AddDate, GetDate()) = 0 THEN '0 Current'  
               WHEN DateDiff(week, ORDERS.AddDate, GetDate()) > 5 THEN '6 Week++'  
               ELSE CAST(DateDiff(week, ORDERS.AddDate, GetDate()) as NVARCHAR(2) ) + ' Week'  
          END AS Aging, 
         CASE ORDERS.Status WHEN '0' THEN '0-Normal' 
                   WHEN '1' THEN '1-Partial Allocated'  
                   WHEN '2' THEN '2-Fully Allocated' 
                   WHEN '3' THEN '3-Picking' 
                   WHEN '5' THEN '5-Picked' 
                  END AS Status ,  
          COUNT(Distinct ORDERS.OrderKey) AS NoOfOrders,  
          COUNT(1) AS OrderLines, 
          SUM(ORDERDETAIL.OpenQty) As TotUnits 
   FROM   ORDERS WITH (NOLOCK) 
   JOIN  ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey 
   WHERE  ORDERS.Status NOT IN ('9', 'CANC')  
   AND    (ORDERS.StorerKey BETWEEN @StorerKeyStart AND @StorerKeyEnd) 
   AND    (ORDERS.Facility BETWEEN @FacilityStart AND @FacilityEnd) 
   GROUP BY CASE WHEN DateDiff(week, ORDERS.AddDate, GetDate()) = 0 THEN '0 Current' 
               WHEN DateDiff(week, ORDERS.AddDate, GetDate()) > 5 THEN '6 Week++' 
               ELSE CAST(DateDiff(week, ORDERS.AddDate, GetDate()) as NVARCHAR(2) ) + ' Week' 
          END, 
                CASE ORDERS.Status WHEN '0' THEN '0-Normal' 
           WHEN '1' THEN '1-Partial Allocated' 
                   WHEN '2' THEN '2-Fully Allocated' 
                   WHEN '3' THEN '3-Picking' 
                   WHEN '5' THEN '5-Picked' 
                  END  
   ORDER BY 1 DESC, 2
   
   SELECT 'Order Ageing By Orders' AS Title, 
          StatusDesc, 
          SUM(CASE WHEN  WeekRange = '0 Current' THEN NoOfOrders ELSE 0 END) AS Week01,
          SUM(CASE WHEN  WeekRange = '1 Week'    THEN NoOfOrders ELSE 0 END) AS Week02,
          SUM(CASE WHEN  WeekRange = '2 Week'    THEN NoOfOrders ELSE 0 END) AS Week03,
          SUM(CASE WHEN  WeekRange = '3 Week'    THEN NoOfOrders ELSE 0 END) AS Week04,
          SUM(CASE WHEN  WeekRange = '4 Week'    THEN NoOfOrders ELSE 0 END) AS Week05,
          SUM(CASE WHEN  WeekRange = '5 Week'    THEN NoOfOrders ELSE 0 END) AS Week06,          
          SUM(CASE WHEN  WeekRange = '6 Week++'  THEN NoOfOrders ELSE 0 END) AS Week07
   FROM #Result r     
   GROUP BY StatusDesc    
   UNION ALL       
   SELECT 'Order Ageing By Order Lines' AS Title, 
          StatusDesc, 
          SUM(CASE WHEN  WeekRange = '0 Current' THEN OrderLines ELSE 0 END) AS Week01,
          SUM(CASE WHEN  WeekRange = '1 Week'    THEN OrderLines ELSE 0 END) AS Week02,
          SUM(CASE WHEN  WeekRange = '2 Week'    THEN OrderLines ELSE 0 END) AS Week03,
          SUM(CASE WHEN  WeekRange = '3 Week'    THEN OrderLines ELSE 0 END) AS Week04,
          SUM(CASE WHEN  WeekRange = '4 Week'    THEN OrderLines ELSE 0 END) AS Week05,
          SUM(CASE WHEN  WeekRange = '5 Week'    THEN OrderLines ELSE 0 END) AS Week06,          
          SUM(CASE WHEN  WeekRange = '6 Week++'  THEN OrderLines ELSE 0 END) AS Week07
   FROM #Result r     
   GROUP BY StatusDesc    
   UNION ALL
   SELECT 'Order Ageing By Total Units' AS Title, 
          StatusDesc, 
          SUM(CASE WHEN  WeekRange = '0 Current' THEN TotUnits ELSE 0 END) AS Week01,
          SUM(CASE WHEN  WeekRange = '1 Week'    THEN TotUnits ELSE 0 END) AS Week02,
          SUM(CASE WHEN  WeekRange = '2 Week'    THEN TotUnits ELSE 0 END) AS Week03,
          SUM(CASE WHEN  WeekRange = '3 Week'    THEN TotUnits ELSE 0 END) AS Week04,
          SUM(CASE WHEN  WeekRange = '4 Week'    THEN TotUnits ELSE 0 END) AS Week05,
          SUM(CASE WHEN  WeekRange = '5 Week'    THEN TotUnits ELSE 0 END) AS Week06,          
          SUM(CASE WHEN  WeekRange = '6 Week++'  THEN TotUnits ELSE 0 END) AS Week07
   FROM #Result r     
   GROUP BY StatusDesc    
       
END

GO