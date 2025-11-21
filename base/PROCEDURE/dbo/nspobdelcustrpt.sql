SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOBDelCustRpt                                    */
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

CREATE PROC [dbo].[nspOBDelCustRpt] (
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

   DECLARE	@DeliveryDate			DateTime,
   @Day					 NVARCHAR(3),
   @TotalOrder_1			Int, @TotalOrder_2			Int, @TotalOrder_3		Int, @TotalOrder_4		Int,
   @TotalOrder_5			Int, @TotalOrder_6			Int, @TotalOrder_OTH		Int, @TotalOrder_Tot		Int,
   @TotalOrder_S			Int, @TotalOrder_M			Int, @TotalOrder_P		Int, @TotalOrder_CY		Int,
   @TotalOrder_7			Int, @TotalOrder_8			Int, @TotalOrder_9		Int, @TotalOrder_10		Int,
   @TotalOrder_GT			Int,
   @Total1_2Carton_1		Int, @Total1_2Carton_2		Int, @Total1_2Carton_3		Int, @Total1_2Carton_4		Int,
   @Total1_2Carton_5		Int, @Total1_2Carton_6		Int, @Total1_2Carton_OTH	Int, @Total1_2Carton_Tot	Int,
   @Total1_2Carton_S		Int, @Total1_2Carton_M		Int, @Total1_2Carton_P		Int, @Total1_2Carton_CY		Int,
   @Total1_2Carton_7		Int, @Total1_2Carton_8		Int, @Total1_2Carton_9		Int, @Total1_2Carton_10		Int,
   @Total1_2Carton_GT	Int,
   @Total3_5Carton_1		Int, @Total3_5Carton_2		Int, @Total3_5Carton_3		Int, @Total3_5Carton_4		Int,
   @Total3_5Carton_5		Int, @Total3_5Carton_6		Int, @Total3_5Carton_OTH	Int, @Total3_5Carton_Tot	Int,
   @Total3_5Carton_S		Int, @Total3_5Carton_M		Int, @Total3_5Carton_P		Int, @Total3_5Carton_CY		Int,
   @Total3_5Carton_7		Int, @Total3_5Carton_8		Int, @Total3_5Carton_9		Int, @Total3_5Carton_10		Int,
   @Total3_5Carton_GT	Int,
   @TotalQty_1				Int, @TotalQty_2				Int, @TotalQty_3				Int, @TotalQty_4				Int,
   @TotalQty_5				Int, @TotalQty_6				Int, @TotalQty_OTH			Int, @TotalQty_Tot			Int,
   @TotalQty_S				Int, @TotalQty_M				Int, @TotalQty_P				Int, @TotalQty_CY				Int,
   @TotalQty_7				Int, @TotalQty_8				Int, @TotalQty_9				Int, @TotalQty_10				Int,
   @TotalQty_GT			Int,
   @TotalCarton_1			Int, @TotalCarton_2			Int, @TotalCarton_3			Int, @TotalCarton_4			Int,
   @TotalCarton_5			Int, @TotalCarton_6			Int, @TotalCarton_OTH		Int, @TotalCarton_Tot		Int,
   @TotalCarton_S			Int, @TotalCarton_M			Int, @TotalCarton_P			Int, @TotalCarton_CY			Int,
   @TotalCarton_7			Int, @TotalCarton_8			Int, @TotalCarton_9			Int, @TotalCarton_10			Int,
   @TotalCarton_GT		Int
   CREATE TABLE #RESULT
   (Week					 NVARCHAR(10) null,
   DeliveryDate			DateTime,
   Day					 NVARCHAR(3),
   TotalOrder_1			Int,
   Total1_2Carton_1		Int,
   Total3_5Carton_1		Int,
   TotalQty_1				Int,
   TotalCarton_1			Int,
   TotalOrder_2			Int,
   Total1_2Carton_2		Int,
   Total3_5Carton_2		Int,
   TotalQty_2				Int,
   TotalCarton_2			Int,
   TotalOrder_3			Int,
   Total1_2Carton_3		Int,
   Total3_5Carton_3		Int,
   TotalQty_3				Int,
   TotalCarton_3			Int,
   TotalOrder_4			Int,
   Total1_2Carton_4		Int,
   Total3_5Carton_4		Int,
   TotalQty_4				Int,
   TotalCarton_4			Int,
   TotalOrder_5			Int,
   Total1_2Carton_5		Int,
   Total3_5Carton_5		Int,
   TotalQty_5				Int,
   TotalCarton_5			Int,
   TotalOrder_6			Int,
   Total1_2Carton_6		Int,
   Total3_5Carton_6		Int,
   TotalQty_6				Int,
   TotalCarton_6			Int,
   TotalOrder_7			Int,
   Total1_2Carton_7		Int,
   Total3_5Carton_7		Int,
   TotalQty_7				Int,
   TotalCarton_7			Int,
   TotalOrder_8			Int,
   Total1_2Carton_8		Int,
   Total3_5Carton_8		Int,
   TotalQty_8				Int,
   TotalCarton_8			Int,
   TotalOrder_9			Int,
   Total1_2Carton_9		Int,
   Total3_5Carton_9		Int,
   TotalQty_9				Int,
   TotalCarton_9			Int,
   TotalOrder_10			Int,
   Total1_2Carton_10	Int,
   Total3_5Carton_10	Int,
   TotalQty_10			Int,
   TotalCarton_10		Int,
   TotalOrder_OTH		Int,
   Total1_2Carton_OTH	Int,
   Total3_5Carton_OTH	Int,
   TotalQty_OTH			Int,
   TotalCarton_OTH		Int,
   TotalOrder_Tot		Int,
   Total1_2Carton_Tot	Int,
   Total3_5Carton_Tot	Int,
   TotalQty_Tot			Int,
   TotalCarton_Tot		Int,
   TotalOrder_S			Int,
   Total1_2Carton_S		Int,
   Total3_5Carton_S		Int,
   TotalQty_S				Int,
   TotalCarton_S			Int,
   TotalOrder_M			Int,
   Total1_2Carton_M		Int,
   Total3_5Carton_M		Int,
   TotalQty_M				Int,
   TotalCarton_M			Int,
   TotalOrder_P			Int,
   Total1_2Carton_P		Int,
   Total3_5Carton_P		Int,
   TotalQty_P				Int,
   TotalCarton_P			Int,
   TotalOrder_CY			Int,
   Total1_2Carton_CY	Int,
   Total3_5Carton_CY	Int,
   TotalQty_CY			Int,
   TotalCarton_CY		Int,
   TotalOrder_GT			Int,
   Total1_2Carton_GT	Int,
   Total3_5Carton_GT	Int,
   TotalQty_GT			Int,
   TotalCarton_GT		Int )
   INSERT INTO #RESULT (DeliveryDate)
   SELECT Distinct convert(char(10), deliverydate, 121) As deliverydate
   FROM Orders (nolock)
   WHERE ORDERS.StorerKey = @StorerKey
   AND ORDERS.DeliveryDate >= @DateMin AND ORDERS.DeliveryDate < DATEADD(dd, 1, @DateMax)
   AND ORDERS.ORDERKEY >= @OrderKeyMin AND ORDERS.ORDERKEY <= @OrderKeyMax
   AND ORDERS.EXTERNORDERKEY >= @ExternOrderKeyMin AND ORDERS.EXTERNORDERKEY <= @ExternOrderKeyMax
   and orders.status = '9'
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
   /*********************************************************************************************/
   /*  2. Get Total Count of Orders for Cust1, 2, 3, 4, 5, 6, Others, SG, MAL, PH based on date */
   /*********************************************************************************************/

   select SUBSTRING(ConsigneeKey, 4, 4) as consigneekey, count(orderkey) as total_order
   into #temp_orders
   from orders (nolock)
   WHERE storerkey = @StorerKey
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   and status = '9'
   group by SUBSTRING(ConsigneeKey, 4, 4)

   select @totalorder_1 = 0, @totalorder_2 = 0, @totalorder_3 = 0, @totalorder_4 = 0, @totalorder_5 = 0,
   @totalorder_6 = 0, @totalorder_7 = 0, @totalorder_8 = 0, @totalorder_9 = 0, @totalorder_10 = 0,
   @totalorder_oth = 0

   select @totalorder_1 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0001'

   select @totalorder_2 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0002'

   select @totalorder_3 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0012'

   select @totalorder_4 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0068'

   select @totalorder_5 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0166'

   select @totalorder_6 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0224'

   select @totalorder_7 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0254'

   select @totalorder_8 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0417'

   select @totalorder_9 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0439'

   select @totalorder_10 = isnull(total_order, 0)
   from #temp_orders
   where consigneekey = '0446'

   select @totalorder_oth = isnull(sum(total_order), 0)
   from #temp_orders
   where consigneekey not in ('0001', '0002', '0012', '0068', '0166', '0224', '0254', '0417', '0439', '0446')

   drop table #temp_orders

   SELECT @TotalOrder_Tot = @TotalOrder_1 + @TotalOrder_2 + @TotalOrder_3 + @TotalOrder_4 +
   @TotalOrder_5 + @TotalOrder_6 + @TotalOrder_7 + @TotalOrder_8 +
   @TotalOrder_9 + @TotalOrder_10 + @TotalOrder_OTH

   select @totalorder_s = 0, @totalorder_m = 0, @totalorder_p = 0

   select route, count(orderkey) as total_order
   into #temp_route
   FROM Orders (nolock)
   WHERE storerkey = @StorerKey
   AND Route in ('95','96', '97')
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND ORDERKEY >= @OrderKeyMin AND ORDERKEY <= @OrderKeyMax
   AND EXTERNORDERKEY >= @ExternOrderKeyMin AND EXTERNORDERKEY <= @ExternOrderKeyMax
   and status = '9'
   group by route

   select @totalorder_s = total_order
   from #temp_route
   where route = '95'

   select @totalorder_m = total_order
   from #temp_route
   where route = '97'

   select @totalorder_p = total_order
   from #temp_route
   where route = '96'

   drop table #temp_route

   SELECT @TotalOrder_CY = @TotalOrder_S + @TotalOrder_M + @TotalOrder_P
   SELECT @TotalOrder_GT = @TotalOrder_Tot + @TotalOrder_CY

   /*************************************************************************************************/
   /*  3. Get Total Count of ShippedQty for Cust1, 2, 3, 4, 5, 6, Others, SG, MAL, PH based on date */
   /*************************************************************************************************/
   select SUBSTRING(ConsigneeKey, 4, 4) as consigneekey, sum(shippedqty) as total_shipped
   into #temp_ship
   from orders (nolock) join orderdetail (nolock)
   on orders.orderkey = orderdetail.orderkey
   WHERE orders.storerkey = @StorerKey
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND orders.ORDERKEY >= @OrderKeyMin AND orders.ORDERKEY <= @OrderKeyMax
   AND orders.EXTERNORDERKEY >= @ExternOrderKeyMin AND orders.EXTERNORDERKEY <= @ExternOrderKeyMax
   group by SUBSTRING(orders.ConsigneeKey, 4, 4)

   select @totalqty_1 = 0, @totalqty_2 = 0, @totalqty_3 = 0, @totalqty_4 = 0, @totalqty_5 = 0, @totalqty_6 = 0,
   @totalqty_7 = 0, @totalqty_8 = 0, @totalqty_9 = 0, @totalqty_10 = 0, @totalqty_oth = 0

   select @totalqty_1 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0001'

   select @totalqty_2 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0002'

   select @totalqty_3 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0012'

   select @totalqty_4 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0068'

   select @totalqty_5 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0166'

   select @totalqty_6 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0224'

   select @totalqty_7 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0254'

   select @totalqty_8 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0417'

   select @totalqty_9 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0439'

   select @totalqty_10 = isnull(total_shipped, 0)
   from #temp_ship
   where consigneekey = '0446'

   select @totalqty_oth = isnull(sum(total_shipped), 0)
   from #temp_ship
   where consigneekey not in ('0001', '0002', '0012', '0068', '0166', '0224', '0254', '0417', '0439', '0446')

   drop table #temp_ship

   SELECT @TotalQty_Tot = @TotalQty_1 + @TotalQty_2 + @TotalQty_3 + @TotalQty_4 +
   @TotalQty_5 + @TotalQty_6 + @TotalQty_7 + @TotalQty_8 +
   @TotalQty_9 + @TotalQty_10 + @TotalQty_OTH

   select @totalqty_s = 0, @totalqty_m = 0, @totalqty_p = 0

   select route, sum(shippedqty) as total_shipped
   into #temp_route1
   FROM Orders (nolock) join orderdetail (nolock)
   on orders.orderkey = orderdetail.orderkey
   WHERE orders.storerkey = @StorerKey
   AND orders.Route in ('95','96', '97')
   AND DeliveryDate >= @DeliveryDate AND DeliveryDate < DATEADD(dd, 1, @DeliveryDate)
   AND orders.ORDERKEY >= @OrderKeyMin AND orders.ORDERKEY <= @OrderKeyMax
   AND orders.EXTERNORDERKEY >= @ExternOrderKeyMin AND orders.EXTERNORDERKEY <= @ExternOrderKeyMax
   group by route

   select @totalqty_s = total_shipped
   from #temp_route1
   where route = '95'

   select @totalqty_m = total_shipped
   from #temp_route1
   where route = '97'

   select @totalqty_p = total_shipped
   from #temp_route1
   where route = '96'

   drop table #temp_route1

   SELECT @TotalQty_CY = @TotalQty_S + @TotalQty_M + @TotalQty_P
   SELECT @TotalQty_GT = @TotalQty_Tot + @TotalQty_CY
   /***************************************************************************************************************/
   /*   4.Get Total Count of Orders with No.of Carton for Cust1, 2, 3, 4, 5, 6, Others, SG, MAL, PH based on date */
   /***************************************************************************************************************/
   select o.orderkey
   , cust_grp = max(substring(o.consigneekey,4,4))
, ctn1_2 = (case when max(cartonno) > 0 and max(cartonno) <= 2 then 1 else 0 end)
, ctn3_5 = (case when max(cartonno) > 2 and max(cartonno) <= 5 then 1 else 0 end)
   , ttn_ctn = max(cartonno)
   into #temp_ctn
   from packdetail pd (nolock), packheader ph (nolock), orders o (nolock)
   where pd.pickslipno = ph.pickslipno
   and o.storerkey = @storerkey
   and o.orderkey = ph.orderkey
   and o.deliverydate >= @deliverydate and o.deliverydate < dateadd(dd, 1, @deliverydate)
   and o.orderkey >= @orderkeymin and o.orderkey <= @orderkeymax
   and o.externorderkey >= @externorderkeymin and o.externorderkey <= @externorderkeymax
   and o.status = '9'
   group by o.orderkey
   --1-0001
   select @total1_2carton_1 = sum(ctn1_2), @total3_5carton_1 = sum(ctn3_5), @totalcarton_1 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0001'
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
   --2-0002
   select @total1_2carton_2 = sum(ctn1_2), @total3_5carton_2 = sum(ctn3_5), @totalcarton_2 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0002'
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
   --3-0012
   select @total1_2carton_3 = sum(ctn1_2), @total3_5carton_3 = sum(ctn3_5), @totalcarton_3 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0012'
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
   --4-0068
   select @total1_2carton_4 = sum(ctn1_2), @total3_5carton_4 = sum(ctn3_5), @totalcarton_4 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0068'
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
   --5-0166
   select @total1_2carton_5 = sum(ctn1_2), @total3_5carton_5 = sum(ctn3_5), @totalcarton_5 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0166'
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
   --6-0224
   select @total1_2carton_6 = sum(ctn1_2), @total3_5carton_6 = sum(ctn3_5), @totalcarton_6 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0224'
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
   --7-0254
   select @total1_2carton_7 = sum(ctn1_2), @total3_5carton_7 = sum(ctn3_5), @totalcarton_7 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0254'
   IF @total1_2carton_7 >= 0
   Begin
      SELECT @total1_2carton_7 = @total1_2carton_7
   End
Else
   Begin
      SELECT @total1_2carton_7 = 0
   End
   IF @total3_5carton_7 >= 0
   Begin
      SELECT @total3_5carton_7 = @total3_5carton_7
   End
Else
   Begin
      SELECT @total3_5carton_7 = 0
   End
   IF @totalcarton_7 >= 0
   Begin
      SELECT @totalcarton_7 = @totalcarton_7
   End
Else
   Begin
      SELECT @totalcarton_7 = 0
   End
   --8-0417
   select @total1_2carton_8 = sum(ctn1_2), @total3_5carton_8 = sum(ctn3_5), @totalcarton_8 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0417'
   IF @total1_2carton_8 >= 0
   Begin
      SELECT @total1_2carton_8 = @total1_2carton_8
   End
Else
   Begin
      SELECT @total1_2carton_8 = 0
   End
   IF @total3_5carton_8 >= 0
   Begin
      SELECT @total3_5carton_8 = @total3_5carton_8
   End
Else
   Begin
      SELECT @total3_5carton_8 = 0
   End
   IF @totalcarton_8 >= 0
   Begin
      SELECT @totalcarton_8 = @totalcarton_8
   End
Else
   Begin
      SELECT @totalcarton_8 = 0
   End
   --9-0439
   select @total1_2carton_9 = sum(ctn1_2), @total3_5carton_9 = sum(ctn3_5), @totalcarton_9 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0439'
   IF @total1_2carton_9 >= 0
   Begin
      SELECT @total1_2carton_9 = @total1_2carton_9
   End
Else
   Begin
      SELECT @total1_2carton_9 = 0
   End
   IF @total3_5carton_9 >= 0
   Begin
      SELECT @total3_5carton_9 = @total3_5carton_9
   End
Else
   Begin
      SELECT @total3_5carton_9 = 0
   End
   IF @totalcarton_9 >= 0
   Begin
      SELECT @totalcarton_9 = @totalcarton_9
   End
Else
   Begin
      SELECT @totalcarton_9 = 0
   End
   --10-0446
   select @total1_2carton_10 = sum(ctn1_2), @total3_5carton_10 = sum(ctn3_5), @totalcarton_10 = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp = '0446'
   IF @total1_2carton_10 >= 0
   Begin
      SELECT @total1_2carton_10 = @total1_2carton_10
   End
Else
   Begin
      SELECT @total1_2carton_10 = 0
   End
   IF @total3_5carton_10 >= 0
   Begin
      SELECT @total3_5carton_10 = @total3_5carton_10
   End
Else
   Begin
      SELECT @total3_5carton_10 = 0
   End
   IF @totalcarton_10 >= 0
   Begin
      SELECT @totalcarton_10 = @totalcarton_10
   End
Else
   Begin
      SELECT @totalcarton_10 = 0
   End
   --OTH
   select @total1_2carton_oth = sum(ctn1_2), @total3_5carton_oth = sum(ctn3_5), @totalcarton_oth = sum(ttn_ctn)
   from   #temp_ctn
   where  cust_grp not in ('0001', '0002', '0012', '0068', '0166', '0224', '0254', '0417', '0439', '0446')
   IF @total1_2carton_oth >= 0
   Begin
      SELECT @total1_2carton_oth = @total1_2carton_oth
   End
Else
   Begin
      SELECT @total1_2carton_oth = 0
   End
   IF @total3_5carton_oth >= 0
   Begin
      SELECT @total3_5carton_oth = @total3_5carton_oth
   End
Else
   Begin
      SELECT @total3_5carton_oth = 0
   End
   IF @totalcarton_oth >= 0
   Begin
      SELECT @totalcarton_oth = @totalcarton_oth
   End
Else
   Begin
      SELECT @totalcarton_oth = 0
   End
   select @total1_2carton_Tot = sum(ctn1_2), @total3_5carton_Tot = sum(ctn3_5), @totalcarton_Tot = sum(ttn_ctn)
   from   #temp_ctn
   drop table #temp_ctn
   select o.orderkey
   , cust_route = max(o.route)
, ctn1_2 = (case when max(cartonno) > 0 and max(cartonno) <= 2 then 1 else 0 end)
, ctn3_5 = (case when max(cartonno) > 2 and max(cartonno) <= 5 then 1 else 0 end)
   , ttn_ctn = max(cartonno)
   into #temp_ctn1
   from packdetail pd (nolock), packheader ph (nolock), orders o (nolock)
   where pd.pickslipno = ph.pickslipno
   and o.orderkey = ph.orderkey
   and o.deliverydate >= @deliverydate and o.deliverydate < dateadd(dd, 1, @deliverydate)
   and o.orderkey >= @orderkeymin and o.orderkey <= @orderkeymax
   and o.externorderkey >= @externorderkeymin and o.externorderkey <= @externorderkeymax
   and o.status = '9'
   and o.route in ('95','97','96')
   group by o.orderkey
   --95-Singapore
   select @total1_2carton_S = sum(ctn1_2), @total3_5carton_S = sum(ctn3_5), @totalcarton_S = sum(ttn_ctn)
   from   #temp_ctn1
   where  cust_route = '95'
   IF @total1_2carton_S >= 0
   Begin
      SELECT @total1_2carton_S = @total1_2carton_S
   End
Else
   Begin
      SELECT @total1_2carton_S = 0
   End
   IF @total3_5carton_S >= 0
   Begin
      SELECT @total3_5carton_S = @total3_5carton_S
   End
Else
   Begin
      SELECT @total3_5carton_S = 0
   End
   IF @totalcarton_S >= 0
   Begin
      SELECT @totalcarton_S = @totalcarton_S
   End
Else
   Begin
      SELECT @totalcarton_S = 0
   End
   --97-Malaysia
   select @total1_2carton_M = sum(ctn1_2), @total3_5carton_M = sum(ctn3_5), @totalcarton_M = sum(ttn_ctn)
   from   #temp_ctn1
   where  cust_route = '97'
   IF @total1_2carton_M >= 0
   Begin
      SELECT @total1_2carton_M = @total1_2carton_M
   End
Else
   Begin
      SELECT @total1_2carton_M = 0
   End
   IF @total3_5carton_M >= 0
   Begin
      SELECT @total3_5carton_M = @total3_5carton_M
   End
Else
   Begin
      SELECT @total3_5carton_M = 0
   End
   IF @totalcarton_M >= 0
   Begin
      SELECT @totalcarton_M = @totalcarton_M
   End
Else
   Begin
      SELECT @totalcarton_M = 0
   End
   --96-Philippine
   select @total1_2carton_P = sum(ctn1_2), @total3_5carton_P = sum(ctn3_5), @totalcarton_P = sum(ttn_ctn)
   from   #temp_ctn1
   where  cust_route = '96'
   IF @total1_2carton_P >= 0
   Begin
      SELECT @total1_2carton_P = @total1_2carton_P
   End
Else
   Begin
      SELECT @total1_2carton_P= 0
   End
   IF @total3_5carton_P>= 0
   Begin
      SELECT @total3_5carton_P = @total3_5carton_P
   End
Else
   Begin
      SELECT @total3_5carton_P = 0
   End
   IF @totalcarton_P >= 0
   Begin
      SELECT @totalcarton_P = @totalcarton_P
   End
Else
   Begin
      SELECT @totalcarton_P = 0
   End
   select @total1_2carton_CY = sum(ctn1_2), @total3_5carton_CY = sum(ctn3_5), @totalcarton_CY = sum(ttn_ctn)
   from   #temp_ctn1
   IF @total1_2carton_CY >= 0
   Begin
      SELECT @total1_2carton_CY = @total1_2carton_CY
   End
Else
   Begin
      SELECT @total1_2carton_CY= 0
   End
   IF @total3_5carton_CY>= 0
   Begin
      SELECT @total3_5carton_CY = @total3_5carton_CY
   End
Else
   Begin
      SELECT @total3_5carton_CY = 0
   End
   IF @totalcarton_CY >= 0
   Begin
      SELECT @totalcarton_CY = @totalcarton_CY
   End
Else
   Begin
      SELECT @totalcarton_CY = 0
   End
   drop table #temp_ctn1
   select @Total1_2Carton_GT = @Total1_2Carton_Tot + @Total1_2Carton_CY
   ,      @Total3_5Carton_GT = @Total3_5Carton_Tot + @Total3_5Carton_CY
   ,      @TotalCarton_Gt    = @TotalCarton_Tot + @TotalCarton_CY
   /**************************************/
   /* Update the data back to Temp table */
   /**************************************/
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
   TotalOrder_7 = @TotalOrder_7, Total1_2Carton_7 = @Total1_2Carton_7,
   Total3_5Carton_7 = @Total3_5Carton_7, TotalQty_7 = @TotalQty_7, TotalCarton_7 = @TotalCarton_7,
   TotalOrder_8 = @TotalOrder_8, Total1_2Carton_8 = @Total1_2Carton_8,
   Total3_5Carton_8 = @Total3_5Carton_8, TotalQty_8 = @TotalQty_8, TotalCarton_8 = @TotalCarton_8,
   TotalOrder_9 = @TotalOrder_9, Total1_2Carton_9 = @Total1_2Carton_9,
   Total3_5Carton_9 = @Total3_5Carton_9, TotalQty_9 = @TotalQty_9, TotalCarton_9 = @TotalCarton_9,
   TotalOrder_10 = @TotalOrder_10, Total1_2Carton_10 = @Total1_2Carton_10,
   Total3_5Carton_10 = @Total3_5Carton_10, TotalQty_10 = @TotalQty_10, TotalCarton_10 = @TotalCarton_10,
   TotalOrder_OTH = @TotalOrder_OTH, Total1_2Carton_OTH = @Total1_2Carton_OTH,
   Total3_5Carton_OTH = @Total3_5Carton_OTH, TotalQty_OTH = @TotalQty_OTH, TotalCarton_OTH = @TotalCarton_OTH,
   TotalOrder_Tot = @TotalOrder_Tot, Total1_2Carton_Tot = @Total1_2Carton_Tot,
   Total3_5Carton_Tot = @Total3_5Carton_Tot, TotalQty_Tot = @TotalQty_Tot, TotalCarton_Tot = @TotalCarton_Tot,
   TotalOrder_S = @TotalOrder_S, Total1_2Carton_S = @Total1_2Carton_S,
   Total3_5Carton_S = @Total3_5Carton_S, TotalQty_S = @TotalQty_S, TotalCarton_S = @TotalCarton_S,
   TotalOrder_M = @TotalOrder_M, Total1_2Carton_M = @Total1_2Carton_M,
   Total3_5Carton_M = @Total3_5Carton_M, TotalQty_M = @TotalQty_M, TotalCarton_M = @TotalCarton_M,
   TotalOrder_P = @TotalOrder_P, Total1_2Carton_P = @Total1_2Carton_P,
   Total3_5Carton_P = @Total3_5Carton_P, TotalQty_P = @TotalQty_P, TotalCarton_P = @TotalCarton_P,
   TotalOrder_CY = @TotalOrder_CY, Total1_2Carton_CY = @Total1_2Carton_CY,
   Total3_5Carton_CY = @Total3_5Carton_CY, TotalQty_CY = @TotalQty_CY, TotalCarton_CY = @TotalCarton_CY,
   TotalOrder_GT = @TotalOrder_GT, Total1_2Carton_GT = @Total1_2Carton_GT,
   Total3_5Carton_GT = @Total3_5Carton_GT, TotalQty_GT = @TotalQty_GT, TotalCarton_GT = @TotalCarton_GT
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
TotalOrder_7, Total1_2Carton_7, Total3_5Carton_7, TotalQty_7, TotalCarton_7,
TotalOrder_8, Total1_2Carton_8, Total3_5Carton_8, TotalQty_8, TotalCarton_8,
TotalOrder_9, Total1_2Carton_9, Total3_5Carton_9, TotalQty_9, TotalCarton_9,
TotalOrder_10, Total1_2Carton_10, Total3_5Carton_10, TotalQty_10, TotalCarton_10,
TotalOrder_OTH, Total1_2Carton_OTH, Total3_5Carton_OTH, TotalQty_OTH, TotalCarton_OTH,
TotalOrder_Tot, Total1_2Carton_Tot, Total3_5Carton_Tot, TotalQty_Tot, TotalCarton_Tot,
TotalOrder_S, Total1_2Carton_S, Total3_5Carton_S, TotalQty_S, TotalCarton_S,
TotalOrder_M, Total1_2Carton_M, Total3_5Carton_M, TotalQty_M, TotalCarton_M,
TotalOrder_P, Total1_2Carton_P, Total3_5Carton_P, TotalQty_P, TotalCarton_P,
TotalOrder_CY, Total1_2Carton_CY, Total3_5Carton_CY, TotalQty_CY, TotalCarton_CY,
TotalOrder_GT, Total1_2Carton_GT, Total3_5Carton_GT, TotalQty_GT, TotalCarton_GT
FROM #RESULT
DROP Table #RESULT
set nocount off
END


GO