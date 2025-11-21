SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOBDelRegnRpt                                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/************************************************************************/

/*
exec nspOBDelRegnRpt
'niketh','2001-10-01','2001-10-31','0','z','0','z'
*/
CREATE PROC [dbo].[nspOBDelRegnRpt] (
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

   DECLARE	@DeliveryDate	DateTime,
   @Day			 NVARCHAR(3),
   @TotalOrder_1	Int, @Total1_2Carton_1	Int, @Total3_5Carton_1	Int, @TotalQty_1	Int, @TotalCarton_1	Int,
   @TotalOrder_2	Int, @Total1_2Carton_2	Int, @Total3_5Carton_2	Int, @TotalQty_2	Int, @TotalCarton_2	Int,
   @TotalOrder_3	Int, @Total1_2Carton_3	Int, @Total3_5Carton_3	Int, @TotalQty_3	Int, @TotalCarton_3	Int,
   @TotalOrder_4	Int, @Total1_2Carton_4	Int, @Total3_5Carton_4	Int, @TotalQty_4	Int, @TotalCarton_4	Int,
   @TotalOrder_5	Int, @Total1_2Carton_5	Int, @Total3_5Carton_5	Int, @TotalQty_5	Int, @TotalCarton_5	Int,
   @TotalOrder_6	Int, @Total1_2Carton_6	Int, @Total3_5Carton_6	Int, @TotalQty_6	Int, @TotalCarton_6	Int,
   @TotalOrder_T	Int, @Total1_2Carton_T	Int, @Total3_5Carton_T	Int, @TotalQty_T	Int, @TotalCarton_T 	Int
   CREATE TABLE #RESULT
   (Week			 NVARCHAR(10),
   DeliveryDate			DateTime,
   Day			 NVARCHAR(3),
   TotalOrder_1			Int,
   Total1_2Carton_1		Int,
   Total3_5Carton_1		Int,
   TotalQty_1			Int,
   TotalCarton_1			Int,
   TotalOrder_2			Int,
   Total1_2Carton_2		Int,
   Total3_5Carton_2		Int,
   TotalQty_2			Int,
   TotalCarton_2			Int,
   TotalOrder_3			Int,
   Total1_2Carton_3		Int,
   Total3_5Carton_3		Int,
   TotalQty_3			Int,
   TotalCarton_3			Int,
   TotalOrder_4			Int,
   Total1_2Carton_4		Int,
   Total3_5Carton_4		Int,
   TotalQty_4			Int,
   TotalCarton_4			Int,
   TotalOrder_5			Int,
   Total1_2Carton_5		Int,
   Total3_5Carton_5		Int,
   TotalQty_5			Int,
   TotalCarton_5			Int,
   TotalOrder_6			Int,
   Total1_2Carton_6		Int,
   Total3_5Carton_6		Int,
   TotalQty_6			Int,
   TotalCarton_6			Int,
   TotalOrder_T			Int,
   Total1_2Carton_T		Int,
   Total3_5Carton_T		Int,
   TotalQty_T			Int,
   TotalCarton_T			Int )
   INSERT INTO #RESULT (DeliveryDate)
   SELECT Distinct convert(char(10), deliverydate, 121) As deliverydate
   FROM Orders (nolock)
   WHERE ORDERS.StorerKey = @StorerKey
   AND ORDERS.DeliveryDate >= @DateMin AND ORDERS.DeliveryDate < DATEADD(dd, 1, @DateMax)
   AND ORDERS.ORDERKEY >= @OrderKeyMin AND ORDERS.ORDERKEY <= @OrderKeyMax
   AND ORDERS.EXTERNORDERKEY >= @ExternOrderKeyMin AND ORDERS.EXTERNORDERKEY <= @ExternOrderKeyMax
   and orders.status >= '5'
   ORDER BY deliverydate
   DECLARE CUR_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT DeliveryDate
   FROM #RESULT
   OPEN CUR_1
   FETCH NEXT FROM CUR_1 INTO @DeliveryDate

   WHILE (@@fetch_status <> -1)
   BEGIN
      /*  1. Get the day of week */
      SELECT @Day = case datepart(dw, @DeliveryDate)
      When 1 Then 'SUN'
      When 2 Then 'MON'
      When 3 Then 'TUE'
      When 4 Then 'WED'
      When 5 Then 'THU'
      When 6 Then 'FRI'
      When 7 Then 'SAT'
   End
   /**************************************************************************************************/
   /*  2. Get Total Count of Orders for Region 1(Bangkok), 2(South), 3(North), 4(East) based on date */
   /**************************************************************************************************/
   --1-BKK
   SELECT @TotalOrder_1 = COUNT(OrderKey)
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND Route IN ('16', '17', '18', '19', '21', '22', '23', '24', '25', '26',
   '27', '28', '29', '30', '31', '32', '33', '95', '96', '97', '99')
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   and orders.status >= '5'
   IF @TotalOrder_1 >= 0
   Begin
      Select @TotalOrder_1 = @TotalOrder_1
   End
Else
   Begin
      Select @TotalOrder_1 = 0
   End
   --2-SOUTH
   SELECT @TotalOrder_2 = COUNT(OrderKey)
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND Route IN ('01', '02')
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   and orders.status >= '5'
   IF @TotalOrder_2 >= 0
   Begin
      Select @TotalOrder_2 = @TotalOrder_2
   End
Else
   Begin
      Select @TotalOrder_2 = 0
   End
   --3-NORTH
   SELECT @TotalOrder_3 = COUNT(OrderKey)
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND Route IN ('03', '07')
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   and orders.status >= '5'
   IF @TotalOrder_3 >= 0
   Begin
      Select @TotalOrder_3 = @TotalOrder_3
   End
Else
   Begin
      Select @TotalOrder_3 = 0
   End
   --4-EAST
   SELECT @TotalOrder_4 = COUNT(OrderKey)
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND Route IN ('04')
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   and orders.status >= '5'
   IF @TotalOrder_4 >= 0
   Begin
      Select @TotalOrder_4 = @TotalOrder_4
   End
Else
   Begin
      Select @TotalOrder_4 = 0
   End
   --5-CENTRAL
   SELECT @TotalOrder_5 = COUNT(OrderKey)
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND Route IN ('08')
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   and orders.status >= '5'
   IF @TotalOrder_5 >= 0
   Begin
      Select @TotalOrder_5 = @TotalOrder_5
   End
Else
   Begin
      Select @TotalOrder_5 = 0
   End
   --6-NORTH-EAST
   SELECT @TotalOrder_6 = COUNT(OrderKey)
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND Route IN ('05', '06')
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   and orders.status >= '5'
   IF @TotalOrder_6 >= 0
   Begin
      Select @TotalOrder_6 = @TotalOrder_6
   End
Else
   Begin
      Select @TotalOrder_6 = 0
   End
   SELECT @TotalOrder_T = @TotalOrder_1 + @TotalOrder_2 + @TotalOrder_3 + @TotalOrder_4 + @TotalOrder_5 + @TotalOrder_6
   /******************************************************************************************************/
   /*  3. Get Total Count of ShippedQty for Region 1(Bangkok), 2(South), 3(North), 4(East) based on date */
   /******************************************************************************************************/
   --1-BKK
   SELECT @TotalQty_1 = SUM(QtyPicked + ShippedQty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND OH.Route IN ('16', '17', '18', '19', '21', '22', '23', '24', '25', '26',
   '27', '28', '29', '30', '31', '32', '33', '95', '96', '97', '99')
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND oh.status >= '5'
   IF @TotalQty_1 >= 0
   Begin
      Select @TotalQty_1 = @TotalQty_1
   End
Else
   Begin
      Select @TotalQty_1 = 0
   End
   --2-SOUTH
   SELECT @TotalQty_2 = SUM(QtyPicked + ShippedQty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND OH.Route IN ('01', '02')
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND oh.status >= '5'
   IF @TotalQty_2 >= 0
   Begin
      Select @TotalQty_2 = @TotalQty_2
   End
Else
   Begin
      Select @TotalQty_2 = 0
   End
   --3-NORTH
   SELECT @TotalQty_3 = SUM(QtyPicked + ShippedQty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND OH.Route IN ('03', '07')
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND oh.status >= '5'
   IF @TotalQty_3 >= 0
   Begin
      Select @TotalQty_3 = @TotalQty_3
   End
Else
   Begin
      Select @TotalQty_3 = 0
   End
   --4-EAST
   SELECT @TotalQty_4 = SUM(QtyPicked + ShippedQty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND Route IN ('04')
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND oh.status >= '5'
   IF @TotalQty_4 >= 0
   Begin
      Select @TotalQty_4 = @TotalQty_4
   End
Else
   Begin
      Select @TotalQty_4 = 0
   End
   --5-CENTRAL
   SELECT @TotalQty_5 = SUM(QtyPicked + ShippedQty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND Route IN ('08')
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND oh.status >= '5'
   IF @TotalQty_5 >= 0
   Begin
      Select @TotalQty_5 = @TotalQty_5
   End
Else
   Begin
      Select @TotalQty_5 = 0
   End
   --6-NORTH-EAST
   SELECT @TotalQty_6 = SUM(QtyPicked + ShippedQty)
   FROM orders OH (nolock), orderdetail OD (nolock)
   WHERE OD.orderkey = OH.orderkey
   AND OH.StorerKey = @StorerKey
   AND Route IN ('05','06')
   AND OH.DeliveryDate >= @DeliveryDate AND OH.DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND OH.ORDERKEY >= @OrderKeyMin AND OH.ORDERKEY <= @OrderKeyMax
   AND OH.EXTERNORDERKEY >= @ExternOrderKeyMin AND OH.EXTERNORDERKEY <= @ExternOrderKeyMax
   AND oh.status >= '5'
   IF @TotalQty_6 >= 0
   Begin
      Select @TotalQty_6 = @TotalQty_6
   End
Else
   Begin
      Select @TotalQty_6 = 0
   End
   SELECT @TotalQty_T = @TotalQty_1 + @TotalQty_2 + @TotalQty_3 + @TotalQty_4 + @TotalQty_5 + @TotalQty_6
   /********************************************************************************************************************/
   /*  4. Get Total Count of Orders with No.of Carton for Region 1(Bangkok), 2(South), 3(North), 4(East) based on date */
   /********************************************************************************************************************/
   select o.orderkey
   , cust_route = max(o.route)
, ctn1_2 = (case when max(cartonno) > 0 and max(cartonno) <= 2 then 1 else 0 end)
, ctn3_5 = (case when max(cartonno) > 2 and max(cartonno) <= 5 then 1 else 0 end)
   , ttn_ctn = max(cartonno)
   into #temp_ctn1
   from packdetail pd (nolock), packheader ph (nolock), orders o (nolock)
   where pd.pickslipno = ph.pickslipno
   and o.storerkey = @storerkey
   and o.orderkey = ph.orderkey
   and o.deliverydate >= @deliverydate and o.deliverydate < dateadd(dd, 1, @deliverydate)
   and o.orderkey >= @orderkeymin and o.orderkey <= @orderkeymax
   and o.externorderkey >= @externorderkeymin and o.externorderkey <= @externorderkeymax
   and o.status >= '5'
   group by o.orderkey
   --1-BKK
   select @total1_2carton_1 = sum(ctn1_2), @total3_5carton_1 = sum(ctn3_5), @totalcarton_1 = sum(ttn_ctn)
   from   #temp_ctn1
   where  cust_route in ('16', '17', '18', '19', '21', '22', '23', '24', '25', '26',
   '27', '28', '29', '30', '31', '32', '33', '95', '96', '97', '99')
   IF @total1_2carton_1 >= 0
   Begin
      SELECT @total1_2carton_1 = @total1_2carton_1
   End
Else
   Begin
      SELECT @total1_2carton_1 = 0
   End
   IF @total3_5carton_1 >= 0
   Begin
      SELECT @total3_5carton_1 = @total3_5carton_1
   End
Else
   Begin
      SELECT @total3_5carton_1 = 0
   End
   IF @totalcarton_1 >= 0
   Begin
      SELECT @totalcarton_1 = @totalcarton_1
   End
Else
   Begin
      SELECT @totalcarton_1 = 0
   End
   --2-South
   select @total1_2carton_2 = sum(ctn1_2), @total3_5carton_2 = sum(ctn3_5), @totalcarton_2 = sum(ttn_ctn)
   from   #temp_ctn1
   where  cust_route in ('01', '02')
   IF @total1_2carton_2 >= 0
   Begin
      SELECT @total1_2carton_2 = @total1_2carton_2
   End
Else
   Begin
      SELECT @total1_2carton_2 = 0
   End
   IF @total3_5carton_2 >= 0
   Begin
      SELECT @total3_5carton_2 = @total3_5carton_2
   End
Else
   Begin
      SELECT @total3_5carton_2 = 0
   End
   IF @totalcarton_2 >= 0
   Begin
      SELECT @totalcarton_2 = @totalcarton_2
   End
Else
   Begin
      SELECT @totalcarton_2 = 0
   End
   --3-North
   select @total1_2carton_3 = sum(ctn1_2), @total3_5carton_3 = sum(ctn3_5), @totalcarton_3 = sum(ttn_ctn)
   from   #temp_ctn1
   where  cust_route in ('03', '07')
   IF @total1_2carton_3 >= 0
   Begin
      SELECT @total1_2carton_3 = @total1_2carton_3
   End
Else
   Begin
      SELECT @total1_2carton_3 = 0
   End
   IF @total3_5carton_3 >= 0
   Begin
      SELECT @total3_5carton_3 = @total3_5carton_3
   End
Else
   Begin
      SELECT @total3_5carton_3 = 0
   End
   IF @totalcarton_3 >= 0
   Begin
      SELECT @totalcarton_3 = @totalcarton_3
   End
Else
   Begin
      SELECT @totalcarton_3 = 0
   End
   --4-East
   select @total1_2carton_4 = sum(ctn1_2), @total3_5carton_4 = sum(ctn3_5), @totalcarton_4 = sum(ttn_ctn)
   from   #temp_ctn1
   where  cust_route in ('04')
   IF @total1_2carton_4 >= 0
   Begin
      SELECT @total1_2carton_4 = @total1_2carton_4
   End
Else
   Begin
      SELECT @total1_2carton_4 = 0
   End
   IF @total3_5carton_4 >= 0
   Begin
      SELECT @total3_5carton_4 = @total3_5carton_4
   End
Else
   Begin
      SELECT @total3_5carton_4 = 0
   End
   IF @totalcarton_4 >= 0
   Begin
      SELECT @totalcarton_4 = @totalcarton_4
   End
Else
   Begin
      SELECT @totalcarton_4 = 0
   End
   --5-CENTRAL
   select @total1_2carton_5 = sum(ctn1_2), @total3_5carton_5 = sum(ctn3_5), @totalcarton_5 = sum(ttn_ctn)
   from   #temp_ctn1
   where  cust_route in ('08')
   IF @total1_2carton_5 >= 0
   Begin
      SELECT @total1_2carton_5 = @total1_2carton_5
   End
Else
   Begin
      SELECT @total1_2carton_5 = 0
   End
   IF @total3_5carton_5 >= 0
   Begin
      SELECT @total3_5carton_5 = @total3_5carton_5
   End
Else
   Begin
      SELECT @total3_5carton_5 = 0
   End
   IF @totalcarton_5 >= 0
   Begin
      SELECT @totalcarton_5 = @totalcarton_5
   End
Else
   Begin
      SELECT @totalcarton_5 = 0
   End
   --6-NORTH-EAST
   select @total1_2carton_6 = sum(ctn1_2), @total3_5carton_6 = sum(ctn3_5), @totalcarton_6 = sum(ttn_ctn)
   from   #temp_ctn1
   where  cust_route in ('05','06')
   IF @total1_2carton_6 >= 0
   Begin
      SELECT @total1_2carton_6 = @total1_2carton_6
   End
Else
   Begin
      SELECT @total1_2carton_6 = 0
   End
   IF @total3_5carton_6 >= 0
   Begin
      SELECT @total3_5carton_6 = @total3_5carton_6
   End
Else
   Begin
      SELECT @total3_5carton_6 = 0
   End
   IF @totalcarton_6 >= 0
   Begin
      SELECT @totalcarton_6 = @totalcarton_6
   End
Else
   Begin
      SELECT @totalcarton_6 = 0
   End

   select @Total1_2Carton_T = @Total1_2Carton_1 + @Total1_2Carton_2 + @Total1_2Carton_3 + @Total1_2Carton_4 + @Total1_2Carton_5 + @Total1_2Carton_6
   ,      @Total3_5Carton_T = @Total3_5Carton_1 + @Total3_5Carton_2 + @Total3_5Carton_3 + @Total3_5Carton_4 + @Total3_5Carton_5 + @Total3_5Carton_6
   ,      @TotalCarton_T    = @TotalCarton_1 + @TotalCarton_2 + @TotalCarton_3 + @TotalCarton_4 + @TotalCarton_5 + @TotalCarton_6
   drop table #temp_ctn1

   UPDATE #Result
   SET Day = @Day,
   TotalOrder_1 = @TotalOrder_1, Total1_2Carton_1 = @Total1_2Carton_1,
   Total3_5Carton_1 = @Total3_5Carton_1, TotalQty_1 = @TotalQty_1, TotalCarton_1 = @TotalCarton_1,
   TotalOrder_2 = @TotalOrder_2, Total1_2Carton_2 = @Total1_2Carton_2,
   Total3_5Carton_2 = @Total3_5Carton_2, TotalQty_2 = @TotalQty_2, TotalCarton_2 = @TotalCarton_2,
   TotalOrder_3 = @TotalOrder_3, Total1_2Carton_3 = @Total1_2Carton_3,
   Total3_5Carton_3 = @Total3_5Carton_3, TotalQty_3 = @TotalQty_3, TotalCarton_3 = @TotalCarton_3,
   TotalOrder_4 = @TotalOrder_4, Total1_2Carton_4 = @Total1_2Carton_4,
   Total3_5Carton_4 = @Total3_5Carton_4, TotalQty_4 = @TotalQty_4, TotalCarton_4 = @TotalCarton_4,
   TotalOrder_5 = @TotalOrder_5, Total1_2Carton_5 = @Total1_2Carton_5,
   Total3_5Carton_5 = @Total3_5Carton_5, TotalQty_5 = @TotalQty_5, TotalCarton_5 = @TotalCarton_5,
   TotalOrder_6 = @TotalOrder_6, Total1_2Carton_6 = @Total1_2Carton_6,
   Total3_5Carton_6 = @Total3_5Carton_6, TotalQty_6 = @TotalQty_6, TotalCarton_6 = @TotalCarton_6,
   TotalOrder_T = @TotalOrder_T, Total1_2Carton_T = @Total1_2Carton_T,
   Total3_5Carton_T = @Total3_5Carton_T, TotalQty_T = @TotalQty_T, TotalCarton_T = @TotalCarton_T
   WHERE DeliveryDate = @DeliveryDate
   FETCH NEXT FROM CUR_1 INTO @DeliveryDate
END  /* cursor loop */

CLOSE      CUR_1
DEALLOCATE CUR_1
SELECT Week, DeliveryDate, Day,
TotalOrder_1, Total1_2Carton_1, Total3_5Carton_1, TotalQty_1, TotalCarton_1,
TotalOrder_2, Total1_2Carton_2, Total3_5Carton_2, TotalQty_2, TotalCarton_2,
TotalOrder_3, Total1_2Carton_3, Total3_5Carton_3, TotalQty_3, TotalCarton_3,
TotalOrder_4, Total1_2Carton_4, Total3_5Carton_4, TotalQty_4, TotalCarton_4,
TotalOrder_5, Total1_2Carton_5, Total3_5Carton_5, TotalQty_5, TotalCarton_5,
TotalOrder_6, Total1_2Carton_6, Total3_5Carton_6, TotalQty_6, TotalCarton_6,
TotalOrder_T, Total1_2Carton_T, Total3_5Carton_T, TotalQty_T, TotalCarton_T
FROM #RESULT
DROP TABLE #RESULT
END

GO