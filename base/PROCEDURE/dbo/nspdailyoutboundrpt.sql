SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspDailyOutboundRpt                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspDailyOutboundRpt] (
@StorerKey	        NVARCHAR(15),
@DateMin	        NVARCHAR(10),
@DateMax	        NVARCHAR(10),
@OrderKeyMin            NVARCHAR(10),
@OrderKeyMax            NVARCHAR(10),
@ExternOrderKeyMin      NVARCHAR(30),
@ExternOrderKeyMax      NVARCHAR(30)
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE	@DeliveryDate		DateTime,
   @Day		 NVARCHAR(3),
   @totalorderqty		int,
   @TotalQty		Int,
   @TotalPPL		Int,
   @UrgentOrder		Int,
   @OrderShip		Int,
   @FullOrderShip		Int,
   @Partial_Fill		Int,
   @ShipQty		Int,
   @PickQty		Int,
   @Fill_Rate		Float,
   @OrderDespatch		Int,
   @Del_OnTime		Int,
   @Del_OnTime_Rate	Float,
   @DiffQty		Int,
   @Accuracy		Float,
   @BatchNo	 NVARCHAR(20)
   CREATE TABLE #RESULT
   (Week		 NVARCHAR(10),
   DeliveryDate		DateTime,
   Day		 NVARCHAR(3),
   TotalQty		Int,
   TotalPPL		Int,
   UrgentOrder		Int,
   OrderShip		Int,
   FullOrderShip		Int,
   Partial_Fill		Int,
   Fill_Rate		Float,
   OrderQty		Int,
   ShipQty		Int,
   DiffQty		Int,
   Accuracy		float,
   Average		Int,
   AveragePickQty		Int,
   Ops_staff	 NVARCHAR(10),
   Hours		 NVARCHAR(10),
   Unit_Staff		Float,
   Order_despatch		Int,
   Del_OnTime		Int,
   Del_OnTime_Rate	Float,
   Vas_Qty	 NVARCHAR(10),
   Vas_Hour	 NVARCHAR(10),
   Vas_Remarks	 NVARCHAR(10),
   BatchNo	 NVARCHAR(20))
   /*  1. Get Date */
   -- Use Orders.DeliveryDate
   INSERT INTO #RESULT (DeliveryDate)
   SELECT Distinct convert(char(10), deliverydate, 121) As deliverydate
   FROM Orders (nolock)
   WHERE ORDERS.StorerKey = @StorerKey
   AND ORDERS.DeliveryDate >= @DateMin AND ORDERS.DeliveryDate < DATEADD(dd, 1, @DateMax)
   AND ORDERS.ORDERKEY >= @OrderKeyMin AND ORDERS.ORDERKEY <= @OrderKeyMax
   AND ORDERS.EXTERNORDERKEY >= @ExternOrderKeyMin AND ORDERS.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND ORDERS.SOSTATUS <> 'CANC'
   --		and orders.status >= '5'
   ORDER BY deliverydate
   DECLARE CUR_1 CURSOR FAST_FORWARD READ_ONLY
   FOR  SELECT DeliveryDate FROM #RESULT
   OPEN CUR_1
   FETCH NEXT FROM CUR_1 INTO @DeliveryDate

   WHILE (@@fetch_status <> -1)
   BEGIN
      --  2. Get the day of week
      SELECT @Day = case datepart(dw, @DeliveryDate)
      When 1 Then 'SUN'
      When 2 Then 'MON'
      When 3 Then 'TUE'
      When 4 Then 'WED'
      When 5 Then 'THU'
      When 6 Then 'FRI'
      When 7 Then 'SAT'
   End

   /*  Get Total Order and QTY based on Date */
   --  3. Total requested QTY (Order with sostatus<>'canc')
   SELECT @totalorderqty = SUM(OriginalQty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND OH.SOSTATUS <> 'CANC'
   --  4. Total requested QTY (Order with sostatus<>'canc' and status >= '5')
   SELECT @TotalQty = SUM(OriginalQty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND OH.SOSTATUS <> 'CANC'
   and oh.status >= '5'
   --  5. Total PPL Order (Order with sostatus<>'canc')
   SELECT @TotalPPL = COUNT(distinct externorderkey)
   FROM ORDERS (nolock)
   WHERE storerkey = @StorerKey
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   AND SOSTATUS <> 'CANC'
   --  2.4 Total urgent Order (Order with sostatus<>'canc')
   SELECT @UrgentOrder = COUNT(OrderKey)
   FROM ORDERS (nolock)
   WHERE storerkey = @StorerKey
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   AND Priority = '9'
   AND SOSTATUS <> 'CANC'
   and orders.status >= '5'
   /*  4. Get count of order shipped on the day from mboldetail */
   SELECT @OrderShip = COUNT(OrderKey)
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   -- AND EditDate >= @DeliveryDate AND EditDate < DATEADD(dd, 1, @DeliveryDate)
   -- AND Status = '9'
   AND Status >= '5'
   AND SOSTATUS <> 'CANC'
   /*  5. Get count of order 100% ship based on OrderQty = QtyShipped in Orderdetail */
   SELECT @Partial_Fill = Count(DISTINCT OH.OrderKey)
   FROM Orders OH (nolock), Orderdetail OD (nolock)
   WHERE OD.OrderKey = OH.Orderkey
   AND OH.storerkey = @StorerKey
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   -- AND EditDate >= @DeliveryDate AND EditDate < DATEADD(dd, 1, @DeliveryDate)
   -- AND Status = '9'
   AND OH.Status >= '5'
   AND OH.SOSTATUS <> 'CANC'
   AND shippedqty + qtypicked < Originalqty
   /*
   SELECT @FullOrderShip = COUNT(OrderKey)
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   -- AND EditDate >= @DeliveryDate AND EditDate < DATEADD(dd, 1, @DeliveryDate)
   -- AND Status = '9'
   AND Status >= '5'
   AND SOSTATUS <> 'CANC'
   AND OPENQTY = 0
   */
   SELECT @FullOrderShip = @OrderShip - @Partial_Fill
   /*  6. Percentage of OrderQty/ShippedQty */
   SELECT @ShipQty = SUM(ShippedQty)
   --SELECT @ShipQty = SUM(originalQty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND OH.Status >= '5'
   AND OH.SOSTATUS <> 'CANC'
   IF @ShipQty >= 0
   Begin
      Select @ShipQty = @ShipQty
   End
Else
   Begin
      Select @ShipQty = 0
   End
   SELECT @PickQty = SUM(QtyPicked)
   --SELECT @PickQty = SUM(QtyPicked)  + sum(shippedqty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND OH.Status >= '5'
   AND OH.SOSTATUS <> 'CANC'
   IF @PickQty >= 0
   Begin
      Select @PickQty = @PickQty
   End
Else
   Begin
      Select @PickQty = 0
   End
   SELECT @DiffQty = @TotalQty - (@PickQty + @ShipQty)
   --			SELECT @DiffQty = @TotalQty - @ShipQty
   If @TotalQty > 0
   BEGIN
      --				SELECT @Fill_Rate = ((convert(float,@PickQty) + convert(float,@ShipQty))/Convert(float, @TotalQty)) * 100
      --				SELECT @Fill_Rate = (convert(float,@ShipQty)/Convert(float, @TotalQty)) * 100
      --				SELECT @Accuracy = (convert(float,@DiffQty)/convert(float, @TotalQty)) * 100
      SELECT @Fill_Rate = ((convert(float,@FullOrderShip ))/Convert(float, @OrderShip)) * 100
      SELECT @Accuracy = ((convert(float,@PickQty) + convert(float,@ShipQty))/Convert(float, @TotalQty)) * 100
   END
ELSE
   BEGIN
      SELECT @Fill_Rate = 0
      SELECT @Accuracy = 0
   END
   /*  A. Number of Despatched based on DeliveryDate - PODCust > 0 */
   SELECT @OrderDespatch = COUNT(OrderKey)
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   -- AND EditDate >= @DeliveryDate AND EditDate < DATEADD(dd, 1, @DeliveryDate)
   AND Status = '9'
   AND SOSTATUS <> 'CANC'
   /*  7. Number of Shipped on time based on DeliveryDate - PODCust > 0 */
   SELECT @Del_OnTime = COUNT(OrderKey)
   FROM Orders (nolock), Mbol (nolock)
   WHERE Orders.Mbolkey = Mbol.Mbolkey
   AND Orders.storerkey = @StorerKey
   AND Orders.DeliveryDate >= @DeliveryDate AND Orders.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND Orders.ORDERKEY >= @OrderKeyMin AND Orders.ORDERKEY <= @OrderKeyMax
   AND Orders.EXTERNORDERKEY >= @ExternOrderKeyMin AND Orders.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND Orders.Status = '9'
   --AND Orders.Status >= '5'
   AND Orders.SOSTATUS <> 'CANC'
   AND DATEDIFF(dd, Orders.deliveryDate, Orders.PodCust) <= 0
   /*  8. Percentage of Order delivered onTime / OrderShipped */
   IF @OrderShip > 0 and @orderDespatch > 0
   Begin
      SELECT @Del_OnTime_Rate = (convert(float,@Del_OnTime)/convert(float, @OrderDespatch)) * 100
   End
Else
   Begin
      SELECT @Del_OnTime_Rate = 0
   End

   UPDATE #Result
   SET Day = @Day, TotalQty = @totalorderqty, TotalPPL = @TotalPPL, UrgentOrder = @UrgentOrder,
   OrderShip = @OrderShip, FullOrderShip = @FullOrderShip, Partial_Fill = @Partial_Fill,
   Fill_Rate = @Fill_Rate, OrderQty = @TotalQty, ShipQty = @ShipQty + @PickQty, DiffQty = @DiffQty,
   Accuracy = @Accuracy, Order_despatch = @OrderDespatch, Del_OnTime = @Del_OnTime,
   Del_OnTime_Rate = @Del_OnTime_Rate
   WHERE DeliveryDate = @DeliveryDate
   FETCH NEXT FROM CUR_1 INTO @DeliveryDate
END  /* cursor loop */

CLOSE      CUR_1
DEALLOCATE CUR_1
SELECT Week, DeliveryDate, Day, TotalQty, TotalPPL, UrgentOrder, OrderShip, FullOrderShip, Partial_Fill,
Fill_Rate, OrderQty, ShipQty, DiffQty, Accuracy, Average, AveragePickQty, Ops_staff, Hours,
Unit_Staff, Order_despatch, Del_OnTime, Del_OnTime_Rate, Vas_Qty, Vas_Hour, Vas_Remarks, BatchNo
FROM #RESULT
DROP TABLE #RESULT
END


GO