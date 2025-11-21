SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_batchplanning                                  */
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
/* Date         Author     Purposes                                     */
/* 03-May-2006  YokeBeen   - Changed from retrieve ORDERS.BillToKey to  */
/*                           ORDERS.Consigneekey for populate load into */
/*                           LoadplanDetail.Consigneekey.               */
/*                         - SOS#48848 (YokeBeen01)                     */
/* 13-Sep-2006  Shong      - SOS# 51075 - CBM not followed in Batch     */
/* SHONG01                   Planning (KCPI)   	                        */ 
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/*                                                                      */
/************************************************************************/

/*******************************************************************
* Modification History:
*
* 06/11/2002 Leo Ng  Program rewrite for IDS version 5
* *****************************************************************/

CREATE PROC [dbo].[nsp_batchplanning]
(@c_startroute	    NVARCHAR(10),
@c_endroute		    NVARCHAR(10),
@c_startpriority	 NVARCHAR(10),
@c_endpriority	    NVARCHAR(10),
@c_startcustomer	 NVARCHAR(15),
@c_endcustomer     NVARCHAR(15),
@c_startorderdate  datetime,
@c_endorderdate    datetime,
@c_startordertype  NVARCHAR(10),
@c_endordertype    NVARCHAR(10),
@c_startfacility   NVARCHAR(5),
@c_endfacility     NVARCHAR(5),
@c_startskuclass   NVARCHAR(10),
@c_endskuclass     NVARCHAR(10),
@d_StartDelDate    datetime,
@d_EndDelDate      datetime,
@c_startstorer     NVARCHAR(15),
@c_endstorer       NVARCHAR(15))
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_trucktype            NVARCHAR(10),
   @n_cube                 decimal(15, 4),
   @c_orderkey             NVARCHAR(10),
   @c_priority             NVARCHAR(10),
   @c_route                NVARCHAR(10),
   @c_consigneekey         NVARCHAR(15),
   @d_deliverydate         datetime,
   @d_orderdate            datetime,
   @n_weight               decimal(15, 4),
   @c_externorderkey       NVARCHAR(50),  --tlting_ext
   @c_company              NVARCHAR(50),
   @c_loadlinenumber       NVARCHAR(30),
   @c_loadkey              NVARCHAR(10),
   @n_ttlcube              decimal(15, 4),
   @n_ttlweight            decimal(15, 4),
   @n_err                  int,
   @b_success              int,
   @c_errmsg               NVARCHAR(250),
   @n_truckweight          decimal(15, 4),
   @n_truckcube            decimal(15, 4),
   @c_door                 NVARCHAR(10),
   @c_orderlinenumber      NVARCHAR(5),
   @c_carrierkey           NVARCHAR(15),
   @n_continue             int,
   @c_rdd                  NVARCHAR(30),
   @c_firstloadkey         NVARCHAR(10),
   @c_temploadkey          NVARCHAR(10),
   @c_neworderkey          NVARCHAR(10),
   @c_neworderlinenumber   NVARCHAR(10),
   @c_temporderkey         NVARCHAR(10),
   @c_ordertype            NVARCHAR(10),
   @n_starttcnt            int,
   @c_newflag              NVARCHAR(1),
   @n_cnt                  int,
   @n_tempttlweight        decimal(15, 4),
   @n_tempttlcube          decimal(15, 4),
   @d_finalendorderdate    datetime,
   @n_detected             int,
   @c_newloadkey           NVARCHAR(10),
   @c_oldorderkey          NVARCHAR(10),
   @c_insertorderkey       NVARCHAR(10),
   @n_innercnt             int,
   @c_Facility             NVARCHAR(5),
   @b_debug                int

   --   SELECT @c_startorderdate = CONVERT(DateTime, (CONVERT(Char(11), @c_startorderdate, 106)))
   SELECT @d_finalendorderdate = DATEADD(Day, 1, @c_endorderdate)
   SELECT @d_EndDelDate = DATEADD( day, 1, @d_EndDelDate )
   SELECT @n_continue = 1
   SELECT @n_starttcnt = @@TRANCOUNT
   SELECT @b_debug = 0

   CREATE TABLE #temp_loop
   (OrderKey          NVARCHAR(10),
   Cube              decimal(15, 4),
   Weight            decimal(15, 4),
   ConsigneeKey      NVARCHAR(15),
   Priority          NVARCHAR(10),
   DeliveryDate      datetime,
   OrderDate         datetime,
   ExternOrderKey    NVARCHAR(50),   --tlting_ext
   CompanyName       NVARCHAR(50),
   Door              NVARCHAR(10),
   RDD               NVARCHAR(30),
   OrderLineNumber   NVARCHAR(5),
   OrderType         NVARCHAR(10),
   Route             NVARCHAR(10),
   Facility          NVARCHAR(5))

   CREATE TABLE #temp_order
   (OrderKey          NVARCHAR(10))

   CREATE TABLE #temp_orderdetail
   (OrderKey          NVARCHAR(10),
   OrderLineNumber   NVARCHAR(5),
   Cube              decimal(15, 4),
   Weight            decimal(15, 4),
   OldOrderKey       NVARCHAR(10),
   Route             NVARCHAR(10),
   Facility          NVARCHAR(5))

   CREATE TABLE #temp_load_loop
   (Orderkey          NVARCHAR(10),
   Cube              decimal(15, 4),
   Weight            decimal(15, 4),
   OldOrderKey       NVARCHAR(10))

   CREATE TABLE #temp_load
   (LoadKey           NVARCHAR(10),
   OrderKey          NVARCHAR(10),
   CarrierKey        NVARCHAR(15),
   Route             NVARCHAR(10),
   TruckType         NVARCHAR(15),
   OldOrderKey       NVARCHAR(10),
   Cube              decimal(15, 4),
   Weight            decimal(15, 4),
   Facility          NVARCHAR(5))

   IF @n_continue <> 3
   BEGIN
      DECLARE order_cur CURSOR  FAST_FORWARD READ_ONLY FOR
      SELECT ORDERS.Facility,
      ORDERS.Route,
      SUM(ORDERDETAIL.OpenQty * SKU.StdCube) TtlCube,
      SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt) TtlWeight
      FROM ORDERS (NOLOCK), ORDERDETAIL (NOLOCK), SKU (NOLOCK)
      WHERE ORDERS.OrderKey = ORDERDETAIL.OrderKey
      AND ORDERDETAIL.Sku = SKU.Sku 
      AND ORDERDETAIL.StorerKey = SKU.StorerKey -- SHONG01 
      AND (ORDERS.LoadKey IS NULL OR ORDERS.LoadKey = '')
      AND ORDERS.Route >= @c_startroute
      AND ORDERS.Route <= @c_endroute
      AND ORDERS.Priority >= @c_startpriority
      AND ORDERS.Priority <= @c_endpriority
		-- (YokeBeen01) - Start
      AND ORDERS.ConsigneeKey >= @c_startcustomer
      AND ORDERS.ConsigneeKey <= @c_endcustomer
		-- (YokeBeen01) - End
      AND ORDERS.Type >= @c_startordertype
      AND ORDERS.Type <= @c_endordertype
      AND ORDERS.OrderDate >= @c_startorderdate
      AND ORDERS.OrderDate < @d_finalendorderdate
      AND ORDERS.Facility >= @c_startfacility
      AND ORDERS.Facility <= @c_endfacility
      AND SKU.Itemclass >= @c_startskuclass
      AND SKU.ItemClass <= @c_endskuclass
      AND ORDERS.DeliveryDate >= @d_StartDelDate
      AND ORDERS.DeliveryDate < @d_EndDelDate
      AND ORDERS.StorerKey >= @c_StartStorer
      AND ORDERS.StorerKey <= @c_EndStorer
      GROUP BY ORDERS.Facility, ORDERS.Route
      ORDER BY ORDERS.Facility, ORDERS.Route

      If @b_debug = 1
      BEGIN
         SELECT ORDERS.Facility, ORDERS.Route,
         SUM(ORDERDETAIL.OpenQty * SKU.StdCube) TtlCube,
         SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt) TtlWeight
         FROM ORDERS (NOLOCK), ORDERDETAIL (NOLOCK), SKU (NOLOCK)
         WHERE ORDERS.OrderKey = ORDERDETAIL.OrderKey
         AND ORDERDETAIL.Sku = SKU.Sku
         AND ORDERDETAIL.StorerKey = SKU.StorerKey -- SHONG01 
         AND (ORDERS.LoadKey IS NULL OR ORDERS.LoadKey = '')
         AND ORDERS.Route >= @c_startroute
         AND ORDERS.Route <= @c_endroute
         AND ORDERS.Priority >= @c_startpriority
         AND ORDERS.Priority <= @c_endpriority
			-- (YokeBeen01) - Start
         AND ORDERS.ConsigneeKey >= @c_startcustomer
         AND ORDERS.ConsigneeKey <= @c_endcustomer
			-- (YokeBeen01) - End
         AND ORDERS.Type >= @c_startordertype
         AND ORDERS.Type <= @c_endordertype
         AND ORDERS.OrderDate >= @c_startorderdate
         AND ORDERS.OrderDate < @d_finalendorderdate
         AND ORDERS.Facility >= @c_startfacility
         AND ORDERS.Facility <= @c_endfacility
         AND SKU.Itemclass >= @c_startskuclass
         AND SKU.ItemClass <= @c_endskuclass
         AND ORDERS.DeliveryDate >= @d_StartDelDate
         AND ORDERS.DeliveryDate < @d_EndDelDate
         AND ORDERS.StorerKey >= @c_StartStorer
         AND ORDERS.StorerKey <= @c_EndStorer
         GROUP BY ORDERS.Facility, ORDERS.Route
         ORDER BY ORDERS.Facility, ORDERS.Route
      END

      OPEN order_cur
      FETCH NEXT FROM order_cur INTO @c_Facility, @c_route, @n_ttlcube, @n_ttlweight
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue <> 3
      BEGIN
         /*  To get all the candidates for the load planning */

         INSERT INTO #temp_loop
         SELECT ORDERS.OrderKey,
         SUM(ORDERDETAIL.OpenQty * SKU.StdCube) TtlCube,
         SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt) TtlWeight,
         ISNULL(ORDERS.ConsigneeKey, ''),  -- (YokeBeen01)
         ORDERS.Priority,
         ORDERS.DeliveryDate,
         ORDERS.OrderDate,
         ORDERS.ExternOrderKey, ISNULL(ORDERS.C_Company, ''),
         ISNULL(ORDERS.Door, ''),
         ISNULL(ORDERS.RDD, ''),
         ORDERDETAIL.OrderLineNumber,
         ORDERS.Type,
         @c_route,
         @c_Facility
         FROM ORDERS (NOLOCK), ORDERDETAIL (NOLOCK), SKU (NOLOCK)
         WHERE ORDERS.OrderKey = ORDERDETAIL.OrderKey
         AND ORDERDETAIL.Sku = SKU.Sku 
         AND ORDERDETAIL.StorerKey = SKU.StorerKey -- SHONG01 
         AND (ORDERS.LoadKey IS NULL OR ORDERS.LoadKey = '')
         AND ORDERS.Facility = @c_Facility
         AND ORDERS.Route = @c_route
         AND ORDERS.Priority >= @c_startpriority
         AND ORDERS.Priority <= @c_endpriority
			-- (Yokebeen01) - Start
         AND ORDERS.ConsigneeKey >= @c_startcustomer
         AND ORDERS.ConsigneeKey <= @c_endcustomer
			-- (YokeBeen01) - End
         AND ORDERS.Type >= @c_startordertype
         AND ORDERS.Type <= @c_endordertype
         AND ORDERS.OrderDate >= @c_startorderdate
         AND ORDERS.OrderDate < @d_finalendorderdate
         AND ORDERS.DeliveryDate >= @d_StartDelDate
         AND ORDERS.DeliveryDate < @d_EndDelDate
         AND SKU.Itemclass >= @c_startskuclass
         AND SKU.ItemClass <= @c_endskuclass
         AND ORDERS.StorerKey >= @c_StartStorer
         AND ORDERS.StorerKey <= @c_EndStorer
         GROUP BY ORDERS.Orderkey, ORDERS.ConsigneeKey, ORDERS.Priority,  -- (YokeBeen01)
         ORDERS.DeliveryDate, ORDERS.DeliveryPlace, ORDERS.OrderDate,
         ORDERS.ExternOrderKey, ORDERS.C_Company, ORDERS.Door, ORDERS.RDD,
         ORDERDETAIL.OrderLineNumber, ORDERS.Type

         /*  To get all the candidates for the load planning */
         SELECT @n_truckweight = 0
         SELECT @n_truckcube = 0
         SELECT @c_trucktype = TruckType,
         @c_carrierkey  = CarrierKey,
         @n_truckweight = IsNULL(Weight, 9999999999.99),
         @n_truckcube   = IsNull(Volume, 9999999999.99)
         FROM RouteMaster (NOLOCK)
         WHERE Route = @c_route

         IF @n_truckweight IS NULL SELECT @n_truckweight = 0
         IF @n_truckcube IS NULL SELECT @n_truckcube = 0
         IF @c_trucktype IS NULL SELECT @c_trucktype = ''
         IF @c_carrierkey IS NULL SELECT @c_carrierkey = ''

         /*  To get those orderkey which the total cube is greater than the truck cube  */
         INSERT INTO #temp_orderdetail
         SELECT OrderKey, OrderLineNumber, Cube, Weight, OrderKey, Route, Facility
         FROM  #temp_loop
         WHERE #temp_loop.Route = @c_route
         AND   #temp_loop.Facility = @c_Facility

         /*  Plan the LOAD  */
         INSERT INTO #temp_load_loop
         SELECT OrderKey, SUM(Cube), SUM(Weight), OldOrderKey
         FROM #temp_orderdetail
         WHERE Route = @c_route
         AND Facility = @c_Facility
         GROUP BY OrderKey, OldOrderKey

         SELECT @n_cnt = COUNT(*) FROM #temp_load_loop
         SELECT @n_tempttlcube = 0, @c_temporderkey = '', @c_newloadkey = '', @c_temploadkey = '', @n_tempttlweight = 0

         WHILE @n_cnt <> 0
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_orderkey = OrderKey,
            @n_cube = Cube,
            @n_weight = Weight,
            @c_oldorderkey = OldOrderKey
            FROM #temp_load_loop
            ORDER BY Cube Desc
            SET ROWCOUNT 0

            IF @n_cube > @n_truckcube OR @n_weight > @n_truckweight OR @c_temploadkey = ''
            BEGIN
               SELECT @b_success = 0
               SELECT @n_tempttlcube = @n_cube
               SELECT @n_tempttlweight = @n_weight
               EXECUTE nspg_GetKey
               "LOADKEY",
               10,
               @c_newloadkey  OUTPUT,
               @b_success     OUTPUT,
               @n_err         OUTPUT,
               @c_errmsg      OUTPUT
               IF @b_success = 1
               BEGIN
                  SELECT @n_cnt = @n_cnt - 1
                  SELECT @c_temploadkey = @c_newloadkey

                  INSERT INTO #temp_load
                  VALUES (@c_newloadkey,
                  @c_orderkey,
                  @c_carrierkey,
                  @c_route,
                  @c_trucktype,
                  @c_oldorderkey,
                  @n_cube,
                  @n_weight,
                  @c_Facility)

                  DELETE FROM #temp_load_loop WHERE OrderKey = @c_orderkey
               END
            END
         ELSE
            BEGIN
               IF ((@n_tempttlcube + @n_cube) > @n_truckcube) OR ((@n_tempttlweight + @n_weight) > @n_truckweight)
               BEGIN
                  SELECT @b_success = 0
                  SELECT @n_tempttlcube = @n_cube
                  SELECT @n_tempttlweight = @n_weight
                  EXECUTE nspg_GetKey
                  "LOADKEY",
                  10,
                  @c_newloadkey  OUTPUT,
                  @b_success     OUTPUT,
                  @n_err         OUTPUT,
                  @c_errmsg      OUTPUT

                  IF @b_success = 1
                  BEGIN
                     SELECT @n_cnt = @n_cnt - 1
                     SELECT @c_temploadkey = @c_newloadkey
                     INSERT INTO #temp_load
                     VALUES (@c_newloadkey,
                     @c_orderkey,
                     @c_carrierkey,
                     @c_route,
                     @c_trucktype,
                     @c_oldorderkey,
                     @n_cube,
                     @n_weight,
                     @c_Facility)

                     DELETE FROM #temp_load_loop WHERE OrderKey = @c_orderkey
                  END
               END

               SELECT @c_temporderkey = ''
               SELECT @c_newflag = 'N'
               SELECT @n_innercnt = COUNT(*) FROM #temp_load_loop

               WHILE @n_innercnt <> 0 AND @b_success = 1
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_orderkey = OrderKey,
                  @n_cube = Cube,
                  @n_weight = Weight,
                  @c_oldorderkey = OldOrderKey
                  FROM #temp_load_loop
                  WHERE OrderKey > @c_temporderkey
                  ORDER BY OrderKey
                  SET ROWCOUNT 0

                  IF ((@n_tempttlweight + @n_weight) <= @n_truckweight) AND ((@n_tempttlcube + @n_cube) <= @n_truckcube)
                  BEGIN
                     SELECT @n_cnt = @n_cnt - 1
                     SELECT @n_tempttlcube = @n_tempttlcube + @n_cube
                     SELECT @n_tempttlweight = @n_tempttlweight + @n_weight

                     INSERT INTO #temp_load
                     VALUES (@c_newloadkey,
                     @c_orderkey,
                     @c_carrierkey,
                     @c_route,
                     @c_trucktype,
                     @c_oldorderkey,
                     @n_cube,
                     @n_weight,
                     @c_Facility)

                     DELETE FROM #temp_load_loop WHERE OrderKey = @c_orderkey
                  END

                  SELECT @c_temporderkey = @c_orderkey
                  SELECT @n_innercnt = @n_innercnt - 1
               END
            END
         END

         SELECT @c_temporderkey = '', @c_insertorderkey = ''

         /*  Plan the LOAD  */
         FETCH NEXT FROM order_cur INTO @c_Facility, @c_route, @n_ttlcube, @n_ttlweight
      END -- Open order_cur
      CLOSE order_cur
      DEALLOCATE order_cur

      IF @b_debug = 1
      BEGIN
         Select * from #temp_loop
      END

      /*  To insert records into LoadPlan & LoadPlanDetail  */

      SELECT @c_temploadkey = ''

      DECLARE loaddetail_cur CURSOR  FAST_FORWARD READ_ONLY FOR
      SELECT LoadKey, OrderKey, Route, TruckType, OldOrderKey, Cube, Weight, Facility
      FROM #temp_load
      ORDER BY LoadKey

      OPEN loaddetail_cur
      FETCH NEXT FROM loaddetail_cur INTO @c_loadkey, @c_orderkey, @c_route, @c_trucktype, @c_oldorderkey, @n_cube, @n_weight, @c_Facility
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue <> 3
      BEGIN
         BEGIN TRAN
            IF @c_temploadkey <> @c_loadkey
            BEGIN
               INSERT INTO LoadPlan
               (LoadKey,
               TruckSize,
               CarrierKey,
               Route,
               Facility)
               VALUES
               (@c_loadkey,
               @c_trucktype,
               @c_carrierkey,
               @c_route,
               @c_Facility)

               SELECT @n_err = @@ERROR

               IF @n_err <> 0 SELECT @n_continue = 3
            ELSE
               BEGIN
                  SELECT @c_temploadkey = @c_loadkey
                  SELECT @c_loadlinenumber = 0
               END
            END

            IF @n_continue <> 3
            BEGIN
               SELECT @c_loadlinenumber = dbo.fnc_RTrim(CONVERT(char(5), (CONVERT(int, @c_loadlinenumber) + 1)))
               SELECT @c_loadlinenumber = "0000" + @c_loadlinenumber
               SELECT @c_loadlinenumber = dbo.fnc_RTrim(@c_loadlinenumber)
               SELECT @c_loadlinenumber = RIGHT(@c_loadlinenumber, 5)
               INSERT INTO LoadPlanDetail
               (LoadKey,
               LoadLineNumber,
               OrderKey,
               ConsigneeKey,
               Priority,
               OrderDate,
               DeliveryDate,
               Type,
               Door,
               Weight,
               Cube,
               ExternOrderKey,
               CustomerName,
               Rdd)
               SELECT @c_loadkey,
               @c_loadlinenumber,
               @c_orderkey,
               ConsigneeKey,
               Priority,
               OrderDate,
               DeliveryDate,
               OrderType,
               Door,
               @n_weight,
               @n_cube,
               ExternOrderKey,
               CompanyName,
               Rdd
               FROM #temp_loop
               WHERE #temp_loop.OrderKey = @c_oldorderkey
               GROUP BY ConsigneeKey,
               Priority,
               OrderDate,
               DeliveryDate,
               OrderType,
               Door,
               ExternOrderKey,
               CompanyName,
               Rdd

               SELECT @n_err = @@ERROR

               IF @n_err <> 0 SELECT @n_continue = 3
               IF @n_continue = 3
               BEGIN
                  IF @@TRANCOUNT >= 1
                  BEGIN
                     ROLLBACK TRAN
                  END
               END
            ELSE
               BEGIN
                  COMMIT TRAN
               END
            END
            FETCH NEXT FROM loaddetail_cur INTO @c_loadkey, @c_orderkey, @c_route, @c_trucktype, @c_oldorderkey, @n_cube, @n_weight, @c_Facility
         END
         CLOSE loaddetail_cur
         DEALLOCATE loaddetail_cur
         /*  To insert records into LoadPlan & LoadPlanDetail  */
      END -- @n_continue = 3
   END

GO