SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_BatchPlanning_AllocQty                         */
/* Creation Date: 05-Aug-2002                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Batch Processing - Allocate By Qty (Version 2.0)            */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.14                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Purposes                                       */
/* 12-May-2007	MaryVong  Either Cube or Weight over capacity, must	   */
/*								 compute the full case of CubeQty and WgtQty	   */
/* 10-Sep-2007 Shong     SOS# 85340 Route Allocated Cube and CBM limit  */
/* 14-Mar-2012 KHLim01   Update EditDate                                */ 
/* 29-APR-2014 CSCHONG   Add Lottable06-15 (CS01)                       */ 
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */     
/************************************************************************/
CREATE PROC [dbo].[nsp_BatchPlanning_AllocQty] (
   @c_StartRoute     NVARCHAR(10),
   @c_EndRoute       NVARCHAR(10),
   @c_StartPriority  NVARCHAR(10),
   @c_EndPriority    NVARCHAR(10),
   @c_StartCustomer  NVARCHAR(15),
   @c_EndCustomer    NVARCHAR(15),
   @c_StartOrderDate datetime,
   @c_EndOrderDate   datetime,
   @c_StartOrderType NVARCHAR(10),
   @c_EndOrderType   NVARCHAR(10),
   @c_StartFacility  NVARCHAR(5),
   @c_EndFacility    NVARCHAR(5),
   @d_StartDelDate   datetime,
   @d_EndDelDate     datetime, 
   @c_StartStorer    NVARCHAR(15),
   @c_EndStorer      NVARCHAR(15),
   @c_SplitUOM       NVARCHAR(4))
AS
BEGIN -- main
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE  
      @c_TruckType         NVARCHAR(10),
      @c_OrderKey          NVARCHAR(10),
      @c_Priority          NVARCHAR(10),
      @c_LoadKey           NVARCHAR(10),
      @c_Route             NVARCHAR(10),
      @c_ConsigneeKey      NVARCHAR(15),
      @d_DeliveryDate      datetime,
      @d_OrderDate         datetime,
      @c_ExternOrderKey    NVARCHAR(50),   --tlting_ext
      @c_Company           NVARCHAR(50),
      @c_LoadLineNumber    NVARCHAR(5),
      @n_Err               int,
      @b_Success           int,
      @c_ErrMsg            NVARCHAR(250),
      @c_Door              NVARCHAR(10),
      @c_OrderLineNumber   NVARCHAR(5),
      @c_CarrierKey        NVARCHAR(15),
      @n_Continue          int,
      @c_RDD               NVARCHAR(30),
      @c_PickDetailKey     NVARCHAR(10),
      @c_NewOrderKey       NVARCHAR(10),
      @c_ExternLineNo      NVARCHAR(10),
      @c_NewPickDetailKey  NVARCHAR(10),
      @c_OrderType         NVARCHAR(10),
      @n_Starttcnt         int,
      @c_PickStatus        NVARCHAR(10),
      @n_Cnt               int,
      @d_FinalEndOrderDate datetime,
      @c_NewLoadKey        NVARCHAR(10),
      @c_Facility          NVARCHAR(5),
      @b_debug             int,
      @c_SKU               NVARCHAR(20),
      @n_Cube              decimal(15,6),
      @n_Weight            decimal(15,6),
      @n_TruckWeight       decimal(15,6),
      @n_TruckCube         decimal(15,6),
      @n_StdGrossWgt       decimal(15,6),
      @n_StdCube           decimal(15,6),
      @n_BalCube           decimal(15,6),
      @n_BalWeight         decimal(15,6),				
      @n_WgtQty            decimal(15,6),
      @n_CubeQty           decimal(15,6),
      @n_OpenQty           decimal(15,6),
      @n_BalQty            decimal(15,6),
      @n_BalDrops         int, 
      @c_PrevRoute         NVARCHAR(10),
      @c_PrevConsignee     NVARCHAR(15),
      @c_PrevFacility      NVARCHAR(5),
      @n_Qty               int,
      @n_QtyAllocated      int, 
      @n_NoOfDrops         int,
      @n_NoOfCusts         int,
      @n_CaseCnt    			float,
      @n_Pallet            float,
      @c_LineNo            NVARCHAR(5),
      @c_Status            NVARCHAR(1),
      @c_NewStatus         NVARCHAR(1),
      @n_OriginalQty       int,
      @n_TotalQtyAlloc     int,
      @n_TotalOriginQty    int, 
      @n_TotalOpenQty      int, 
      @n_TotalCarton       int, 
      @n_TotalAllocCarton  int    

   SET NOCOUNT ON      
   
   SELECT @c_StartOrderDate = DATEADD(Day, -1, @c_StartOrderDate)    
   SELECT @d_StartDelDate = DATEADD(Day, -1, @d_StartDelDate) 
   SELECT @d_FinalEndOrderDate = DATEADD(Day, 1, @c_EndOrderDate)    
   SELECT @d_EndDelDate = DATEADD(Day, 1, @d_EndDelDate )
   SELECT @n_continue = 1, @n_Starttcnt=@@TRANCOUNT
   SELECT @n_Starttcnt = @@TRANCOUNT
   SELECT @b_debug = 0
  
   CREATE TABLE #LoadplanLog (LoadKey NVARCHAR(10), OrderKey NVARCHAR(10))
   BEGIN TRAN

	-- ONG01 BEGIN -- Reject when found PreAllocatedQty , get the same condition as below
 	IF @n_continue <> 3
 	BEGIN
		SELECT @c_orderkey = ''
		SET ROWCOUNT  1
 		SELECT @c_orderkey = ORDERS.Orderkey 
 		FROM ORDERS WITH (NOLOCK)	
		JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
 		WHERE (ORDERDETAIL.LoadKey IS NULL OR ORDERDETAIL.LoadKey = '')
 			AND ORDERS.SOStatus = '0'
 			AND ORDERS.Status < '9'
 			AND ORDERS.Route >= @c_startroute
 			AND ORDERS.Route <= @c_endroute
 			AND ORDERS.Priority >= @c_startpriority       
 			AND ORDERS.Priority <= @c_endpriority
 			AND ORDERS.ConsigneeKey >= @c_startcustomer
 			AND ORDERS.ConsigneeKey <= @c_endcustomer
 			AND ORDERS.Type >= @c_startordertype
 			AND ORDERS.Type <= @c_endordertype
 			AND ORDERS.OrderDate > @c_startorderdate
 			AND ORDERS.OrderDate < @d_finalendorderdate 
 			AND ORDERS.Facility >= @c_startfacility
 			AND ORDERS.Facility <= @c_endfacility
 			AND ORDERS.DeliveryDate > @d_StartDelDate  
 			AND ORDERS.DeliveryDate < @d_EndDelDate 
 			AND ORDERS.StorerKey >= @c_startStorer
 			AND ORDERS.StorerKey <= @c_endStorer 
 			AND ORDERDETAIL.QtyAllocated > 0
 			AND ORDERDETAIL.Status < '9'
			AND ORDERDETAIL.QtyPreAllocated > 0
		SET ROWCOUNT 0

		If @c_orderkey <> '' OR @c_orderkey IS NULL
		BEGIN
			SELECT @n_continue = 3  
			SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61800 
			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+ ' Order: ' + @c_orderkey + ' Found QtyPreAllocated! Must clear PreAllocatePickDetail to proceed (nsp_BatchPlanning_AllocQty) '
			GOTO QUIT
		END
	END
	-- ONG01 END -- Reject when found PreAllocatedQty

   START_BATCHPLANNING:

   IF @n_continue <> 3
   BEGIN
      SET @c_PrevRoute      = ''
      SET @c_PrevConsignee  = ''
      SET @c_PrevFacility   = ''
      SET @n_NoOfCusts      = 0 
      SET @n_Weight         = 0
      SET @n_Cube           = 0 
      SET @n_TotalCarton    = 0 
		-- SET @c_LoadKey     = '' 

      IF @b_debug = 2
      BEGIN
         SELECT 
         ORDERS.OrderKey, 
         ORDERS.Facility, 
         ORDERS.Route,
         ROUND(SKU.StdCube, 6) AS StdCube,
         ROUND(SKU.StdGrossWgt, 6) AS StdGrossWgt,
         ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey, 
         ORDERS.Priority, 
         ORDERS.DeliveryDate,
         ORDERS.OrderDate, 
         ORDERS.ExternOrderKey,
         ISNULL(ORDERS.C_Company, '') AS C_Company, 
         ISNULL(ORDERS.Door, '') AS Door, 
         ISNULL(ORDERS.RDD, '') AS RDD, 
         ORDERDETAIL.OrderLineNumber, 
         ORDERDETAIL.ExternLineNo,
         ORDERDETAIL.SKU,
         ORDERS.Type,
         ORDERDETAIL.OpenQty,
         ORDERDETAIL.QtyAllocated, 
         ISNULL(RouteMaster.TruckType, '') AS TruckType,
         ISNULL(RouteMaster.CarrierKey, '') AS CarrierKey,
         ISNULL(RouteMaster.Weight, 999999999.999) AS WeightCapacity,
         ISNULL(RouteMaster.Volume, 999999999.999) AS VolumeCapacity,
			ISNULL(RouteMaster.NoOfDrops, 99999), 
         PACK.CaseCnt,
         PACK.Pallet, 
         ORDERS.Status,
         ORDERDETAIL.OriginalQty   
      FROM ORDERS WITH (NOLOCK) 
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
      JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku )
      JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey )
      JOIN RouteMaster WITH (NOLOCK) ON RouteMaster.Route = ORDERS.Route 
      WHERE (ORDERDETAIL.LoadKey IS NULL OR ORDERDETAIL.LoadKey = '')
         AND ORDERS.SOStatus = '0'
         AND ORDERS.Status < '9'
         AND ORDERS.Route        BETWEEN @c_StartRoute     AND @c_endRoute
         AND ORDERS.Priority     BETWEEN @c_StartPriority  AND @c_EndPriority
         AND ORDERS.ConsigneeKey BETWEEN @c_StartCustomer  AND @c_EndCustomer
         AND ORDERS.Type         BETWEEN @c_StartOrderType AND @c_EndOrderType
         AND ORDERS.OrderDate    BETWEEN @c_StartOrderDate AND @d_FinalEndOrderDate 
         AND ORDERS.Facility     BETWEEN @c_StartFacility  AND @c_EndFacility
         AND ORDERS.DeliveryDate BETWEEN @d_StartDelDate   AND @d_EndDelDate 
         AND ORDERS.StorerKey    BETWEEN @c_StartStorer    AND @c_EndStorer 
         AND ORDERDETAIL.QtyAllocated > 0
         AND ORDERDETAIL.Status < '9'
      END

      -- 1.0 Select All the Orders
      DECLARE ORDER_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT 
         ORDERS.OrderKey, 
         ORDERS.Facility, 
         ORDERS.Route,
         ROUND(SKU.StdCube, 6) AS StdCube,
         ROUND(SKU.StdGrossWgt, 6) AS StdGrossWgt,
         ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey, 
         ORDERS.Priority, 
         ORDERS.DeliveryDate,
         ORDERS.OrderDate, 
         ORDERS.ExternOrderKey,
         ISNULL(ORDERS.C_Company, '') AS C_Company, 
         ISNULL(ORDERS.Door, '') AS Door, 
         ISNULL(ORDERS.RDD, '') AS RDD, 
         ORDERDETAIL.OrderLineNumber, 
         ORDERDETAIL.ExternLineNo,
         ORDERDETAIL.SKU,
         ORDERS.Type,
         ORDERDETAIL.OpenQty,
         ORDERDETAIL.QtyAllocated, 
         ISNULL(RouteMaster.TruckType, '') AS TruckType,
         ISNULL(RouteMaster.CarrierKey, '') AS CarrierKey,
         ISNULL(RouteMaster.Weight, 999999999.999) AS WeightCapacity,
         ISNULL(RouteMaster.Volume, 999999999.999) AS VolumeCapacity,
         ISNULL(RouteMaster.NoOfDrops, 99999), 
         PACK.CaseCnt,
         PACK.Pallet, 
         ORDERS.Status,
         ORDERDETAIL.OriginalQty  
      FROM ORDERS WITH (NOLOCK) 
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
      JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku )
      JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey )
      JOIN RouteMaster WITH (NOLOCK) ON RouteMaster.Route = ORDERS.Route 
      WHERE (ORDERDETAIL.LoadKey IS NULL OR ORDERDETAIL.LoadKey = '')
         AND ORDERS.SOStatus = '0'
         AND ORDERS.Status < '9'
         AND ORDERS.Route        BETWEEN @c_StartRoute     AND @c_endRoute
         AND ORDERS.Priority     BETWEEN @c_StartPriority  AND @c_EndPriority
         AND ORDERS.ConsigneeKey BETWEEN @c_StartCustomer  AND @c_EndCustomer
         AND ORDERS.Type         BETWEEN @c_StartOrderType AND @c_EndOrderType
         AND ORDERS.OrderDate    BETWEEN @c_StartOrderDate AND @d_FinalEndOrderDate 
         AND ORDERS.Facility     BETWEEN @c_StartFacility  AND @c_EndFacility
         AND ORDERS.DeliveryDate BETWEEN @d_StartDelDate   AND @d_EndDelDate 
         AND ORDERS.StorerKey    BETWEEN @c_StartStorer    AND @c_EndStorer 
         AND ORDERDETAIL.QtyAllocated > 0
         AND ORDERDETAIL.Status < '9'
      ORDER BY 
         ORDERS.Facility, 
         ORDERS.Route, 
         ISNULL(ORDERS.ConsigneeKey, ''), 
         ORDERS.OrderKey, 
			ORDERDETAIL.OrderLineNumber

      OPEN ORDER_CUR

      FETCH NEXT FROM ORDER_CUR INTO 
         @c_OrderKey,          @c_Facility,           @c_Route,
         @n_StdCube,           @n_StdGrossWgt,        @c_ConsigneeKey,
         @c_Priority,          @d_DeliveryDate,       @d_OrderDate, 
         @c_ExternOrderKey,    @c_Company,            @c_Door,
         @c_RDD,               @c_OrderLineNumber,    @c_ExternLineNo,
         @c_SKU,               @c_OrderType,          @n_OpenQty,
         @n_QtyAllocated,      @c_TruckType,          @c_CarrierKey,  
         @n_TruckWeight,       @n_TruckCube,          @n_NoOfDrops, 
         @n_CaseCnt,           @n_Pallet,             @c_Status, 
         @n_OriginalQty    

      WHILE @@FETCH_STATUS <> -1
      BEGIN 
         IF @c_PrevConsignee <> @c_ConsigneeKey 
         BEGIN   
            SET @n_NoOfCusts = @n_NoOfCusts + 1 

            IF @b_debug = 1
            BEGIN
               SELECT '1.0' ChkCode, @c_PrevConsignee '@c_PrevConsignee', @c_ConsigneeKey '@c_ConsigneeKey',
                      @n_NoOfCusts '@n_NoOfCusts', @n_NoOfDrops '@n_NoOfDrops'
            END

            SET @c_PrevConsignee = @c_ConsigneeKey
         END 

         -- 2.0 If New Route, Facility or Greate then Max Drops
         IF @c_PrevRoute    <> @c_Route    OR 
            @c_PrevFacility <> @c_Facility OR 
            @n_NoOfDrops    <  @n_NoOfCusts 
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT '2.1' ChkCode, @c_PrevConsignee '@c_PrevConsignee', @c_ConsigneeKey '@c_ConsigneeKey', @c_Route '@c_Route', 
                      @c_Facility '@c_Facility', @n_NoOfCusts '@n_NoOfCusts', @n_NoOfDrops '@n_NoOfDrops'
            END

            -- 2.1 If Previous Load# was exists, then update loapdlan status 
            IF dbo.fnc_RTrim(@c_LoadKey) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey) <> ''
            BEGIN
               -- Get Total QtyAllocated and Original Qty 
               SELECT @n_TotalOriginQty = SUM(O.OriginalQty),
                      @n_TotalQtyAlloc  = SUM(O.QtyAllocated),
                      @n_TotalCarton      = SUM(FLOOR(O.OriginalQty  / CASE WHEN P.CaseCnt > 0 THEN P.CaseCnt ELSE 1 END)),
                      @n_TotalAllocCarton = SUM(FLOOR(O.QtyAllocated / CASE WHEN P.CaseCnt > 0 THEN P.CaseCnt ELSE 1 END))
               FROM  ORDERDETAIL O WITH (NOLOCK)
               JOIN  SKU  S WITH (NOLOCK) ON S.StorerKey = O.StorerKey and S.SKU = O.SKU 
               JOIN  PACK P WITH (NOLOCK) ON P.PackKey = S.PackKey 
               WHERE O.LoadKey = @c_LoadKey
          
               IF @n_TotalOriginQty > @n_TotalQtyAlloc AND @n_TotalQtyAlloc > 0
               BEGIN
                  UPDATE LoadPlan With (ROWLOCK)
                  SET --trafficcop = NULL, --SOS# 85340
                      status = '1', 
                      AllocatedCaseCnt = @n_TotalAllocCarton, 
                      CaseCnt   =  @n_TotalCarton
                  WHERE LoadKey = @c_LoadKey          
                  SET @n_err = @@ERROR      
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE LoadPlan Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                     GOTO QUIT
                  END         
               END
               ELSE IF @n_TotalOriginQty = @n_TotalQtyAlloc
               BEGIN
                  UPDATE LoadPlan With (ROWLOCK)
                    SET -- trafficcop = NULL, -- SOS# 85340
                        status = '2', 
                        AllocatedCaseCnt = @n_TotalAllocCarton, 
                        CaseCnt   =  @n_TotalCarton
                  WHERE LoadKey = @c_LoadKey
      				SET @n_err = @@ERROR      
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61821   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE LoadPlan Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                     GOTO QUIT
                  END         
               END
            END -- 2.1 if Previous Loadkey is not BLANK

            -- 2.2 Get New LoadKey 
            SELECT @b_Success = 0   
            EXECUTE nspg_GetKey
               'LoadKey',
               10,
               @c_LoadKey      OUTPUT,
               @b_Success      OUTPUT,
               @n_err          OUTPUT,
               @c_ErrMsg       OUTPUT                        

            -- 2.3 Insert Record into Loadplan 
            INSERT INTO LoadPlan (LoadKey, TruckSize, CarrierKey, Route, Facility)  
            VALUES  (@c_LoadKey, @c_TruckType, @c_CarrierKey, @c_Route, @c_Facility)
            SET @n_err = @@ERROR    
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61822   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT LoadPlan Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
               GOTO QUIT
            END  
            
            SET @c_PrevRoute     = @c_Route
            SET @c_PrevFacility  = @c_Facility 

            SET @n_NoOfCusts    = 1

            SET @n_BalCube   = @n_TruckCube
            SET @n_BalWeight = @n_TruckWeight 
            SET @n_BalDrops  = @n_NoOfDrops 
            SET @c_LoadLineNumber = '00000' 
            
         END -- 2.0 If New Route, Facility or Greate then Max Drops

         IF @b_debug = 1
         BEGIN
            SELECT 'After 2.0' ChkCode, @c_ExternOrderKey '@c_ExternOrderKey', @c_LoadKey '@c_LoadKey', @c_SKU '@c_SKU',  
            		 @n_BalCube '@n_BalCube',   @n_BalWeight '@n_BalWeight', 
                   @n_QtyAllocated * @n_StdCube 'Current Cube', 
                   @n_QtyAllocated * @n_StdGrossWgt 'Current Weight', 
                   @c_OrderLineNumber '@c_OrderLineNumber', @n_QtyAllocated '@n_QtyAllocated' 
         END

         -- 3.0 Weight AND Cube is OK 
         IF  @n_QtyAllocated * @n_StdCube     < @n_BalCube AND
             @n_QtyAllocated * @n_StdGrossWgt < @n_BalWeight 
         BEGIN
            SET @n_Weight  = (@n_QtyAllocated * @n_StdGrossWgt) 
            SET @n_Cube    = (@n_QtyAllocated * @n_StdCube) 
            SET @n_TotalCarton = FLOOR(@n_QtyAllocated / @n_CaseCnt)

            -- 3.1 Check if the OrderKey already inserted into Loadplan Detail or Not 
            IF NOT EXISTS(SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @c_LoadKey AND OrderKey = @c_OrderKey)
            BEGIN
               SET @c_LoadLineNumber = RIGHT( '0000' + dbo.fnc_RTrim(CONVERT(char(5), (CONVERT(int, @c_LoadLineNumber) + 1))), 5) 
   
               IF @b_debug = 1
               BEGIN
                  Print  ' >>>>> 3.1 INSERT INTO LoadPlan Detail, LoadKey =' + dbo.fnc_RTrim(@c_LoadKey) 
                        + ' Line# ' + dbo.fnc_RTrim(@c_LoadLineNumber) + ' Order# ' + dbo.fnc_RTrim(@c_OrderKey)
               END
   
               INSERT INTO LoadPlanDetail
                  (LoadKey,       LoadLineNumber,
                  OrderKey,       ConsigneeKey,
                  Priority,       OrderDate,
          DeliveryDate,   Type,
                  Door,           Weight,
                  Cube,           ExternOrderKey,
                  CustomerName,   Rdd, 
                  Status,         Route, 
                  CaseCnt)
               VALUES (
            			@c_LoadKey,        @c_LoadLineNumber,
                     @c_OrderKey,       @c_ConsigneeKey,
                     @c_Priority,       @d_OrderDate,
                     @d_DeliveryDate,   @c_OrderType,
                     @c_Door,           @n_Weight,
                     @n_Cube,           @c_ExternOrderKey,
                     @c_Company,        @c_RDD,
                     @c_Status,         @c_Route,
                     @n_TotalCarton)
               SET @n_err = @@ERROR    
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61830   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT LoadPlanDetail Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                  GOTO QUIT
               END  
               IF NOT EXISTS(SELECT 1 FROM #LoadplanLog WHERE LoadKey = @c_LoadKey AND OrderKey = @c_OrderKey)
               BEGIN
                     INSERT INTO #LoadplanLog (LoadKey, OrderKey)
                     VALUES (@c_LoadKey, @c_OrderKey)
               END
                           
               SET @n_Weight         = 0
               SET @n_Cube           = 0 
               SET @n_TotalCarton    = 0 
   
            END -- Not Exists in LoadPlan Detail 
            ELSE
            BEGIN
               UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                  SET Cube    = ISNULL(Cube,0) + (@n_QtyAllocated * @n_StdCube), 
                      Weight  = ISNULL(Weight,0) + (@n_QtyAllocated * @n_StdGrossWgt),
                      CaseCnt = ISNULL(CaseCnt,0) + FLOOR(@n_QtyAllocated / @n_CaseCnt), 
                      EditDate = GETDATE(), -- KHLim01
                      TrafficCop = NULL
               WHERE Loadkey = @c_LoadKey
               AND   OrderKey = @c_OrderKey 
               SET @n_err = @@ERROR    
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61831   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update LOADPLANDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                  GOTO QUIT
               END                    
                      
               UPDATE LOADPLAN WITH (ROWLOCK) 
                  SET Cube = ISNULL(Cube,0) + (@n_QtyAllocated * @n_StdCube), 
                      Weight = ISNULL(Weight,0) + (@n_QtyAllocated * @n_StdGrossWgt),
                      CaseCnt = ISNULL(CaseCnt,0) + FLOOR(@n_QtyAllocated / @n_CaseCnt), 
                      -- Added By Shong on 10th Sep 2007 
                      -- SOS# 85340 Route Allocated weight and CBM limit
                      AllocatedCube = ISNULL(Cube,0) + (@n_QtyAllocated * @n_StdCube), 
                      AllocatedWeight = ISNULL(Weight,0) + (@n_QtyAllocated * @n_StdGrossWgt),
                      AllocatedCaseCnt = ISNULL(CaseCnt,0) + FLOOR(@n_QtyAllocated / @n_CaseCnt), 
                      EditDate = GETDATE(), -- KHLim01
               		 TrafficCop = NULL
               WHERE Loadkey = @c_LoadKey
               SET @n_err = @@ERROR    
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61832   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update LOADPLAN Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                  GOTO QUIT
               END                 

               SET @n_Weight         = 0
               SET @n_Cube           = 0 
               SET @n_TotalCarton    = 0 
            END -- If Exists 

            UPDATE ORDERDETAIL WITH (ROWLOCK)
               SET LoadKey = @c_LoadKey, TrafficCop = NULL
                  ,EditDate = GETDATE() -- KHLim01
            WHERE OrderKey = @c_OrderKey
            AND   OrderLineNumber = @c_OrderLineNumber
            SET @n_err = @@ERROR    
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
       		 		 SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61833   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update ORDERDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
               GOTO QUIT
            END  

            SET @n_BalCube = @n_BalCube - ( @n_QtyAllocated * @n_StdCube )
            SET @n_BalWeight = @n_BalWeight - ( @n_QtyAllocated * @n_StdGrossWgt )
         END -- 3.0 Weigth AND Cube not Exceed truck capacity
         ELSE
         BEGIN -- 4.0 Weight or Cube over truck capacity 
            IF @b_debug = 1
            BEGIN
               PRINT ' --------------  Split Order ------------------- '
            END 
				-- Remarked by MaryVong on 12-May-2007
				-- Either Cube or Weight over capacity, must compute the full case of CubeQty and WgtQty       
				-- 4.1 If Cube is Over Capacity    
				-- IF ( @n_QtyAllocated * @n_StdCube ) > @n_BalCube
				-- BEGIN
				-- Get the Qty By Cube
				IF @n_StdCube > 0
					 SELECT @n_CubeQty = FLOOR(@n_BalCube / @n_StdCube )  
				ELSE
					 SELECT @n_CubeQty = 0
				
				-- Calculate Qty going to remain in ORDERDETAIL 
				-- Assign to the Qty base on max Capacity avail => @n_CubeQty ,ONG01 
				IF @c_SplitUOM = 'CS' 
					SET @n_CubeQty = FLOOR(@n_CubeQty / @n_CaseCnt) * @n_CaseCnt 
				ELSE IF @c_SplitUOM = 'PLT' 
					SET @n_CubeQty = FLOOR(@n_CubeQty / @n_Pallet) * @n_Pallet
				-- END -- 4.1 If Cube is Over Capacity  
		
				-- IF (@n_QtyAllocated * @n_StdGrossWgt ) > @n_BalWeight			-- ONG01
				-- BEGIN -- 4.2 IF Weight > Capacity
				-- Get the Qty By Weight  
				IF @n_StdGrossWgt > 0
					SELECT @n_WgtQty = FLOOR(@n_BalWeight / @n_StdGrossWgt) 	
				ELSE
					SELECT @n_WgtQty = 0
				
				-- Calculate Qty going to remain in ORDERDETAIL 
				-- Assign the Max Qty allow to meet the weight available => @n_WgtQty		          
				IF @c_SplitUOM = 'CS' 
					SET @n_WgtQty = FLOOR(@n_WgtQty / @n_CaseCnt) * @n_CaseCnt		
				ELSE IF @c_SplitUOM = 'PLT' 
					SET @n_WgtQty = FLOOR(@n_WgtQty / @n_Pallet) * @n_Pallet		
				-- END --  4.2 IF Weight > Capacity
				
				-- ONG01 BEGIN
				-- Compare WgtQty and CubeQty, get the whichever smaller to put into this LOAD 
				IF @n_WgtQty > @n_CubeQty 
				BEGIN
					IF @n_StdCube > 0 
						SELECT @n_BalQty = @n_CubeQty
					ELSE
						SELECT @n_BalQty = @n_WgtQty
				END
				ELSE
				BEGIN
					IF @n_StdGrossWgt > 0 
						SELECT @n_BalQty = @n_WgtQty
					ELSE
						SELECT @n_BalQty = @n_CubeQty
				END
				-- ONG01 END

            IF @b_debug = 1
            BEGIN
               SELECT '4.2' ChkCode, @c_ExternOrderKey '@c_ExternOrderKey', @c_LoadKey '@c_LoadKey', 
							@n_BalQty '@n_BalQty', @n_WgtQty '@n_WgtQty', 
							@n_CubeQty '@n_CubeQty' , @n_CaseCnt '@n_CaseCnt' , @n_Pallet '@n_Pallet' 
            END

            -- 5.0 If Qty going to remain in existing loadplan > 0 
            IF @n_BalQty > 0 
            BEGIN
               SET @n_BalCube = 0
               SET @n_BalWeight = 0
               
               -- 5.0.1 If not exists in loadplan detail then insert new record into loadplandetail
            IF NOT EXISTS(SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) 
                             WHERE LoadKey = @c_LoadKey AND OrderKey = @c_OrderKey)
               BEGIN
                  SET @n_Weight = @n_Weight + (@n_BalQty * @n_StdGrossWgt)
                  SET @n_Cube   = @n_Cube   + (@n_BalQty * @n_StdCube) 
                  SET @n_TotalCarton = @n_TotalCarton + FLOOR(@n_QtyAllocated / @n_CaseCnt)
   
                  SET @c_LoadLineNumber = RIGHT( '0000' + dbo.fnc_RTrim(CONVERT(char(5), (CONVERT(int, @c_LoadLineNumber) + 1))), 5) 
      
                  IF @b_debug = 1
                  BEGIN
                     Print  ' >>>>> 5.0 INSERT INTO LoadPlan Detail, LoadKey =' + dbo.fnc_RTrim(@c_LoadKey) 
                           + ' Line# ' + dbo.fnc_RTrim(@c_LoadLineNumber) + ' Order# ' + dbo.fnc_RTrim(@c_OrderKey)
                  END 

                  INSERT INTO LoadPlanDetail
                     (LoadKey,       LoadLineNumber,
                     OrderKey,       ConsigneeKey,
                     Priority,       OrderDate,
                     DeliveryDate,   Type,
                     Door,           Weight,
                     Cube,           ExternOrderKey,
										 CustomerName,   Rdd, 
                     Status,         Route, 
                     CaseCnt)
                  VALUES (
                        @c_LoadKey,        @c_LoadLineNumber,
                        @c_OrderKey,       @c_ConsigneeKey,
                        @c_Priority,       @d_OrderDate,
                        @d_DeliveryDate,   @c_OrderType,
                        @c_Door,           @n_Weight,
                        @n_Cube,           @c_ExternOrderKey,
                        @c_Company,        @c_RDD,
                        @c_Status,         @c_Route,
                        @n_TotalCarton)
                  SET @n_err = @@ERROR    
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61850   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT LoadPlanDetail Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                     GOTO QUIT
                  END  
                  IF NOT EXISTS(SELECT 1 FROM #LoadplanLog WHERE LoadKey = @c_LoadKey AND OrderKey = @c_OrderKey)
                  BEGIN
                        INSERT INTO #LoadplanLog (LoadKey, OrderKey)
                        VALUES (@c_LoadKey, @c_OrderKey)
                  END
                  
                  SET @n_Weight         = 0
                  SET @n_Cube           = 0 
                  SET @n_TotalCarton    = 0 

               END -- Not Exists in LoadPlan Detail 
               ELSE
               BEGIN -- 5.0.2 If order# exists in loadplan detail then update loadplan detail
                  UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                     SET Cube = ISNULL(Cube,0) + (@n_BalQty * @n_StdCube), 
                         Weight = ISNULL(Weight,0) + (@n_BalQty * @n_StdGrossWgt),
                         CaseCnt = ISNULL(CaseCnt,0) + FLOOR(@n_BalQty / @n_CaseCnt), 
                         EditDate = GETDATE(), -- KHLim01
                         TrafficCop = NULL
                  WHERE Loadkey = @c_LoadKey
                  AND   OrderKey = @c_OrderKey 
                  SET @n_err = @@ERROR    
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61851   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update LOADPLANDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                     GOTO QUIT
                  END                    
                         
                  UPDATE LOADPLAN WITH (ROWLOCK) 
                     SET Cube = ISNULL(Cube,0) + (@n_BalQty * @n_StdCube), 
                         Weight = ISNULL(Weight,0) + (@n_BalQty * @n_StdGrossWgt),
                         CaseCnt = ISNULL(CaseCnt,0) + FLOOR(@n_BalQty / @n_CaseCnt), 
                         -- Added By Shong on 10th Sep 2007 
                         -- SOS# 85340 Route Allocated weight and CBM limit
                         AllocatedCube = ISNULL(Cube,0) + (@n_QtyAllocated * @n_StdCube), 
                         AllocatedWeight = ISNULL(Weight,0) + (@n_QtyAllocated * @n_StdGrossWgt),
                         AllocatedCaseCnt = ISNULL(CaseCnt,0) + FLOOR(@n_QtyAllocated / @n_CaseCnt),
                         EditDate = GETDATE(), -- KHLim01
                         TrafficCop = NULL
                  WHERE Loadkey = @c_LoadKey
                  SET @n_err = @@ERROR    
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61852   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update LOADPLAN Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                     GOTO QUIT
                  END                   
               END -- 5.0.2 If order# exists in loadplan detail then update loadplan detail
               
               -- 5.0.3 update orderdetail with loadkey and qty 
               UPDATE ORDERDETAIL WITH (ROWLOCK)
                  SET LoadKey = @c_LoadKey, 
                      QtyAllocated = @n_BalQty, 
                      OpenQty      = @n_BalQty,
                      OriginalQty  = @n_BalQty,
                      Status       = '2', 
                      EditDate = GETDATE(), -- KHLim01
                      TrafficCop = NULL
               WHERE  OrderKey = @c_OrderKey
               AND   OrderLineNumber = @c_OrderLineNumber
               SET @n_err = @@ERROR    
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61853   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update ORDERDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                  GOTO QUIT
               END  

               IF NOT EXISTS(SELECT 1 FROM #LoadplanLog WHERE LoadKey = @c_LoadKey AND OrderKey = @c_OrderKey)
               BEGIN
                     INSERT INTO #LoadplanLog (LoadKey, OrderKey)
                     VALUES (@c_LoadKey, @c_OrderKey)
               END
            
               -- This Qty Allocated going to brought over to new Order Key and Lines
               SET @n_QtyAllocated = @n_QtyAllocated - @n_BalQty
               SET @n_OpenQty = @n_OpenQty - @n_BalQty 

	            IF @b_debug = 1
	            BEGIN
	               Print  ' >>>>> 5.0.2 SPLIT PICKDETAIL for Orders#: ' + dbo.fnc_RTrim(@c_OrderKey) 
	                     + ' Line# ' + dbo.fnc_RTrim(@c_OrderLineNumber) + ' OpenQty= ' + CAST(@n_OpenQty as char) 
								+ ',QtyAlloc= ' + CAST(@n_QtyAllocated AS CHAR)
								+ ',BalQty= ' + CAST(@n_BalQty AS CHAR)
								+ ',@n_Qty= ' + CAST(@n_Qty AS CHAR)
	            END

               -- If Order Line Need to Split 
               DECLARE C_PICKDETAIL_LK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PickDetailKey, Qty, Status  
                  FROM   PickDetail WITH (NOLOCK)
                  WHERE  OrderKey = @c_OrderKey
                  AND    OrderLineNumber = @c_OrderLineNumber
                  ORDER BY PickDetailKey 
   
               OPEN C_PICKDETAIL_LK
   
   FETCH NEXT FROM C_PICKDETAIL_LK INTO @c_PickDetailKey, @n_Qty, @c_PickStatus 
               -- 5.4 Loop until it reach the qty take 
               WHILE @@FETCH_STATUS <> -1
               BEGIN 
                  IF @n_BalQty < @n_Qty 
                  BEGIN
                     -- Update Current PickDetail with Qty Remain into Old Order line
                     UPDATE PickDetail WITH (ROWLOCK)
                        SET Qty = @n_BalQty, TrafficCop = NULL 
                           ,EditDate = GETDATE() -- KHLim01
                     WHERE PickDetailKey = @c_PickDetailKey 
                     SET @n_err = @@ERROR    
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61854   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                        GOTO QUIT
                     END  
   
                     -- Get New OrderKey  
                     SELECT @b_Success = 1  
   
                     EXECUTE nspg_getkey  
                        'ORDER'  
                        , 10  
                        , @c_NewOrderKey OUTPUT  
                        , @b_Success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_ErrMsg OUTPUT  
                     IF NOT @b_Success = 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                     END      
                     ELSE
                     BEGIN		-- Create New Order Header
                        IF @b_debug = 1
                        BEGIN
                           Print '5.0.3 >>>>>> Insert Orders : ' +  @c_NewOrderKey  
                 			END
   
                        SELECT @c_LineNo = dbo.fnc_RTrim('00001')
                        SELECT @c_LineNo = RIGHT(@c_LineNo, 5)                        
   
                        INSERT INTO ORDERS
									(OrderKey ,StorerKey ,ExternOrderKey ,OrderDate ,DeliveryDate ,Priority ,ConsigneeKey
									,C_contact1 ,C_Contact2 ,C_Company ,C_Address1 ,C_Address2 ,C_Address3 ,C_Address4
									,C_City ,C_State ,C_Zip ,C_Country ,C_ISOCntryCode ,C_Phone1 ,C_Phone2 ,C_Fax1
									,C_Fax2 ,C_vat ,BuyerPO ,BillToKey ,B_contact1 ,B_Contact2 ,B_Company ,B_Address1
									,B_Address2 ,B_Address3 ,B_Address4 ,B_City ,B_State ,B_Zip ,B_Country ,B_ISOCntryCode
									,B_Phone1 ,B_Phone2 ,B_Fax1 ,B_Fax2 ,B_Vat ,IncoTerm ,PmtTerm ,Status
									,DischargePlace ,DeliveryPlace ,IntermodalVehicle ,CountryOfOrigin ,CountryDestination
									,UpdateSource ,Type ,OrderGroup ,Door ,Route ,Stop ,Notes ,EffectiveDate ,ContainerType
									,ContainerQty ,BilledContainerQty ,SOStatus ,MBOLKey ,InvoiceNo ,InvoiceAmount ,Salesman
									,GrossWeight ,Capacity ,PrintFlag ,LoadKey ,Rdd ,Notes2 ,SequenceNo ,Rds ,SectionKey
									,Facility ,PrintDocDate ,LabelPrice ,POKey ,ExternPOKey ,XDockFlag ,UserDefine01
									,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05 ,UserDefine06 ,UserDefine07
									,UserDefine08 ,UserDefine09 ,UserDefine10 ,Issued ,DeliveryNote ,PODCust ,PODArrive
									,PODReject ,PODUser ,xdockpokey ,SpecialHandling)  
								SELECT @c_NewOrderKey ,StorerKey ,ExternOrderKey ,OrderDate ,DeliveryDate ,Priority ,ConsigneeKey
   								,C_contact1 ,C_Contact2 ,C_Company ,C_Address1 ,C_Address2 ,C_Address3 ,C_Address4
   								,C_City ,C_State ,C_Zip ,C_Country ,C_ISOCntryCode ,C_Phone1 ,C_Phone2 ,C_Fax1
   								,C_Fax2 ,C_vat ,BuyerPO ,BillToKey ,B_contact1 ,B_Contact2 ,B_Company ,B_Address1
   								,B_Address2 ,B_Address3 ,B_Address4 ,B_City ,B_State ,B_Zip ,B_Country ,B_ISOCntryCode
   								,B_Phone1 ,B_Phone2 ,B_Fax1 ,B_Fax2 ,B_Vat ,IncoTerm ,PmtTerm ,'0'
   								,DischargePlace ,DeliveryPlace ,IntermodalVehicle ,CountryOfOrigin ,CountryDestination
   								,UpdateSource ,Type ,OrderGroup ,Door ,Route ,Stop ,Notes ,EffectiveDate ,ContainerType
   								,ContainerQty ,BilledContainerQty ,'0' , NULL MBOLKey ,InvoiceNo ,InvoiceAmount ,Salesman
   								,GrossWeight ,Capacity ,PrintFlag ,NULL LoadKey ,Rdd ,Notes2 ,SequenceNo ,Rds ,SectionKey
   								,Facility ,PrintDocDate ,LabelPrice ,POKey ,ExternPOKey ,XDockFlag ,UserDefine01
   								,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05 ,UserDefine06 ,UserDefine07
   								,UserDefine08 ,UserDefine09 ,UserDefine10 ,Issued ,DeliveryNote ,PODCust ,PODArrive
   								,PODReject ,PODUser ,xdockpokey ,SpecialHandling
                        FROM  ORDERS WITH (NOLOCK)
                        WHERE ORDERS.OrderKey = @c_OrderKey       
                        SET @n_err = @@ERROR      
                        IF @n_err <> 0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61855   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                           SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into Orders Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                           GOTO QUIT
                        END  
                     END 
                     -- Insert new OrderDetail Line 
                     IF @n_continue <> 3
                     BEGIN
                        -- transfer balance into new order line 
								/*CS01 start*/   
                        INSERT INTO ORDERDETAIL 
   								(OrderKey ,OrderLineNumber ,ExternOrderKey ,ExternLineNo 
   								,Sku ,StorerKey ,ManufacturerSku ,RetailSku ,AltSku ,OpenQty
   								,ShippedQty ,AdjustedQty ,QtyPreAllocated ,QtyAllocated ,QtyPicked ,UOM
   								,PackKey ,PickCode ,CartonGroup ,Lot ,ID ,Facility ,Status
   								,UnitPrice ,Tax01 ,Tax02 ,ExtendedPrice ,UpdateSource ,Lottable01 ,Lottable02
   								,Lottable03 ,Lottable04 ,Lottable05 , Lottable06 ,Lottable07
   								,Lottable08 ,Lottable09 ,Lottable10 , Lottable11 ,Lottable12
   								,Lottable13 ,Lottable14 ,Lottable15 
									,EffectiveDate ,TariffKey ,FreeGoodQty
   								,GrossWeight ,Capacity ,LoadKey ,MBOLKey ,QtyToProcess ,MinShelfLife
   								,UserDefine01 ,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05
   								,UserDefine06 ,UserDefine07 ,UserDefine08 ,UserDefine09
   								,POkey ,ExternPOKey)
   							SELECT @c_NewOrderKey ,@c_LineNo ,ExternOrderKey ,ExternLineNo 
   								,Sku ,StorerKey ,ManufacturerSku ,RetailSku ,AltSku ,@n_OpenQty
   								,0 ShippedQty ,0 AdjustedQty ,0 QtyPreAllocated ,@n_QtyAllocated ,0 QtyPicked ,UOM
   								,PackKey ,PickCode ,CartonGroup ,Lot ,ID ,Facility 
                           ,CASE WHEN @n_QtyAllocated = 0 THEN '0'
                                 WHEN @n_OpenQty = @n_QtyAllocated THEN '2' 
                                 WHEN @n_OpenQty < @n_QtyAllocated THEN '1' 
                                 ELSE '0' 
                            END AS Status 
   								,UnitPrice ,Tax01 ,Tax02 ,ExtendedPrice ,UpdateSource ,Lottable01 ,Lottable02
   								,Lottable03 ,Lottable04 ,Lottable05 , Lottable06 ,Lottable07
   								,Lottable08 ,Lottable09 ,Lottable10 , Lottable11 ,Lottable12
   								,Lottable13 ,Lottable14 ,Lottable15 ,EffectiveDate ,TariffKey ,0 FreeGoodQty
   								,GrossWeight ,Capacity ,NULL LoadKey ,NULL MBOLKey ,0 QtyToProcess ,MinShelfLife
   								,UserDefine01 ,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05
   								,UserDefine06 ,UserDefine07 ,UserDefine08 ,UserDefine09
   								,POkey ,ExternPOKey
                        FROM ORDERDETAIL WITH (NOLOCK)
                        WHERE OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber
								/*CS01 End*/
                        SET @n_err = @@ERROR 
                        IF @n_err <> 0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61856   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                           SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into ORDERDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                           GOTO QUIT
                        END  
                        
                        IF NOT EXISTS(SELECT 1 FROM #LoadplanLog WHERE LoadKey = @c_LoadKey AND OrderKey = @c_OrderKey)
                        BEGIN
                           INSERT INTO #LoadplanLog (LoadKey, OrderKey)
                           VALUES (@c_LoadKey, @c_OrderKey)
                        END                        
                     END  -- Insert new OrderDetail Line        
                     -- Insert New PickDetail  
                     IF @n_continue <> 3
                     BEGIN
                        SET @b_Success = 1 
   
                        EXECUTE  nspg_getkey
                        'PickDetailKey'   
                        , 10
                        , @c_NewPickDetailKey OUTPUT
                        , @b_Success OUTPUT
                        , @n_err     OUTPUT
                        , @c_ErrMsg  OUTPUT
                        IF NOT @b_Success = 1  
                        BEGIN  
                           SELECT @n_continue = 3  
                        END      
                        ELSE
                        BEGIN  -- Transfer balance to new pickdetail key                                              
                           INSERT INTO PICKDETAIL(PickDetailKey, CaseID, PickHeaderKey, OrderKey, 
										OrderLineNumber, Lot, StorerKey, Sku, AltSku, 
										UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, 
										ID, PackKey, UpdateSource, CartonGroup, CartonType, 
										ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, 
										WaveKey, EffectiveDate, AddDate, AddWho, EditDate, EditWho, 
										TrafficCop, ArchiveCop, OptimizeCop, ShipFlag, PickSlipNo)
                           SELECT @c_NewPickDetailKey, CaseID, PickHeaderKey, @c_NewOrderKey, 
										@c_LineNo, Lot, StorerKey, Sku, AltSku, 
										UOM, UOMQty, (@n_Qty - @n_BalQty), QtyMoved, Status, DropID, Loc, 
										ID, PackKey, UpdateSource, CartonGroup, CartonType, 
										ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, 
										WaveKey, EffectiveDate, AddDate, AddWho, EditDate, EditWho, 
										TrafficCop, ArchiveCop, 'N', ShipFlag, PickSlipNo
                           FROM PICKDETAIL WITH (NOLOCK) 
                           WHERE PickDetailKey = @c_PickDetailKey 
   
                           SET @n_err = @@ERROR      
                           IF @n_err <> 0  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61857   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                              SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickDetail Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                              GOTO QUIT
                           END  
                        END -- Insert PickDetail 
                        -- Update the rest of the PickDetail for this Order Line to new Order# and Line 
                        UPDATE PICKDETAIL WITH (ROWLOCK)
                           SET ORDERKEY = @c_NewOrderKey, 
                               ORDERLINENUMBER = @c_LineNo, 
                               EditDate = GETDATE(), -- KHLim01
                               TrafficCop = NULL  
                        WHERE PickDetailKey > @c_PickDetailKey
                        AND   OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber 
                        SET @n_err = @@ERROR      
                        IF @n_err <> 0  
         BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61858   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                           SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                           GOTO QUIT
                        END  
                        
                     END -- @n_continue <> 3 Insert New PickDetail                      
   
                     -- Move the rest of the Order Line to New Order
                     IF @n_continue <> 3
                     BEGIN      
                        DECLARE C_OrdDetUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                        SELECT OrderLineNumber 
                        FROM   ORDERDETAIL WITH (NOLOCK)
                        WHERE  OrderKey = @c_OrderKey
                        AND (ORDERDETAIL.LoadKey IS NULL OR ORDERDETAIL.LoadKey = '')   
                        AND  ORDERDETAIL.QtyAllocated > 0
                        AND  ORDERDETAIL.Status < '9'
                        AND  OrderLineNumber > @c_OrderLineNumber 
   
                        OPEN C_OrdDetUpdate 
   
                        FETCH NEXT FROM C_OrdDetUpdate INTO @c_OrderLineNumber 
   
                        WHILE @@FETCH_STATUS <> -1
                        BEGIN -- While FETCH_STATUS <> -1 
                           SET @c_LineNo = RIGHT( '0000' + dbo.fnc_RTrim(CONVERT(char(5), (CONVERT(int, @c_LineNo) + 1))), 5)
   
                           UPDATE ORDERDETAIL WITH (ROWLOCK)
                              SET OrderLineNumber = @c_LineNo, OrderKey = @c_NewOrderKey, TrafficCop = NULL
                                 ,EditDate = GETDATE() -- KHLim01
                            WHERE OrderKey = @c_OrderKey
                              AND OrderLineNumber = @c_OrderLineNumber 
                           SET @n_err = @@ERROR     
                           IF @n_err <> 0  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61859   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                              SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE ORDERDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                              GOTO QUIT
                           END
   
                           -- Move the rest of pickdetail line to new Order
                           DECLARE C_Update_PickDet_OrderKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                              SELECT PickDetailKey   
                              FROM   PickDetail WITH (NOLOCK)
                              WHERE  OrderKey = @c_OrderKey
                              AND    OrderLineNumber = @c_OrderLineNumber
                              ORDER BY PickDetailKey 
                           
                           OPEN C_Update_PickDet_OrderKey
                           
                           FETCH NEXT FROM C_Update_PickDet_OrderKey INTO @c_PickDetailKey  
                           WHILE @@FETCH_STATUS <> -1
                           BEGIN
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                                 SET OrderLineNumber = @c_LineNo, OrderKey = @c_NewOrderKey, TrafficCop = NULL
                                    ,EditDate = GETDATE() -- KHLim01
                                 WHERE PICKDETAILKEY = @c_PickDetailKey 
                               SET @n_err = @@ERROR     
                               IF @n_err <> 0  
                               BEGIN  
                                 SELECT @n_continue = 3  
                                 SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61860   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                                 SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE PICKDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                                 GOTO QUIT
                               END
   
                              FETCH NEXT FROM C_Update_PickDet_OrderKey INTO @c_PickDetailKey   
                          END 
                           CLOSE C_Update_PickDet_OrderKey
                           DEALLOCATE C_Update_PickDet_OrderKey
   
                           FETCH NEXT FROM C_OrdDetUpdate INTO @c_OrderLineNumber 
                        END -- While FETCH_STATUS <> -1 : Move the rest of the Order Line to New Order
                        CLOSE C_OrdDetUpdate
                        DEALLOCATE C_OrdDetUpdate 
                     END -- if @n_continue <> 3 : Move the rest of the Order Line to New Order

                     -- Recalculate OpenQty For New OrderKey 
                     SELECT @n_TotalOpenQty = SUM(OpenQty) 
                     FROM   ORDERDETAIL WITH (NOLOCK)
                     WHERE  OrderKey = @c_NewOrderKey 
                     
                     -- Update Status for New Order#, Let Trigger to refresh the Order Status 
         				UPDATE ORDERS WITH (ROWLOCK) 
                        SET Status = Status, OpenQty = @n_TotalOpenQty
                     WHERE OrderKey = @c_NewOrderKey 
                     SET @n_err = @@ERROR     
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61861   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE ORDERS Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                        GOTO QUIT
                     END                     
   
                     -- Recalculate OpenQty For Old OrderKey 
                     SELECT @n_TotalOpenQty = SUM(OpenQty) 
                     FROM   ORDERDETAIL WITH (NOLOCK)
                     WHERE  OrderKey = @c_OrderKey 
                     
                     -- Update Status for Old Order#, Let Trigger to refresh the Order Status 
                     UPDATE ORDERS WITH (ROWLOCK) 
                        SET Status = Status, OpenQty = @n_TotalOpenQty  
                     WHERE OrderKey = @c_OrderKey 
                     SET @n_err = @@ERROR     
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61862   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE ORDERS Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                        GOTO QUIT
                     END     
                     
                     -- Close Main Cursor
                     CLOSE ORDER_CUR
                     DEALLOCATE ORDER_CUR
                     CLOSE C_PICKDETAIL_LK
                     DEALLOCATE C_PICKDETAIL_LK 
   
                     -- Goto Declare cursor again 
                     GOTO START_BATCHPLANNING 
                  END -- @n_BalQty < @n_Qty 
                  SET @n_BalQty = @n_BalQty - @n_Qty
                  
                  FETCH NEXT FROM C_PICKDETAIL_LK INTO @c_PickDetailKey, @n_Qty, @c_PickStatus  
               END
               CLOSE C_PICKDETAIL_LK
               DEALLOCATE C_PICKDETAIL_LK 

            END -- 5.0 If Qty going to remain in existing loadplan > 0 
            ELSE
            BEGIN -- @n_BalQty = 0 
        -- if found outstanding order lines 
               if @b_debug = 1	Print '5.0.4'
               IF EXISTS(SELECT 1 FROM OrderDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND 
                          QtyAllocated > 0 AND (LoadKey = '' OR LoadKey IS NULL) ) 
               BEGIN
                  -- Get New OrderKey  
                  SELECT @b_Success = 1  

                  EXECUTE nspg_getkey  
                     'ORDER'  
                     , 10  
                     , @c_NewOrderKey OUTPUT  
                     , @b_Success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_ErrMsg OUTPUT  
                  IF NOT @b_Success = 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                  END                   
                  IF NOT @b_Success = 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                  END      
                  ELSE
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        Print '5.0.4 >>>>>> Insert Orders : ' +  @c_NewOrderKey  
                     END

                     SELECT @c_LineNo = dbo.fnc_RTrim('00001')
                     SELECT @c_LineNo = RIGHT(@c_LineNo, 5)
                     -- Create New Order 

                     INSERT INTO ORDERS
								(OrderKey ,StorerKey ,ExternOrderKey ,OrderDate ,DeliveryDate ,Priority ,ConsigneeKey
								,C_contact1 ,C_Contact2 ,C_Company ,C_Address1 ,C_Address2 ,C_Address3 ,C_Address4
								,C_City ,C_State ,C_Zip ,C_Country ,C_ISOCntryCode ,C_Phone1 ,C_Phone2 ,C_Fax1
								,C_Fax2 ,C_vat ,BuyerPO ,BillToKey ,B_contact1 ,B_Contact2 ,B_Company ,B_Address1
								,B_Address2 ,B_Address3 ,B_Address4 ,B_City ,B_State ,B_Zip ,B_Country ,B_ISOCntryCode
								,B_Phone1 ,B_Phone2 ,B_Fax1 ,B_Fax2 ,B_Vat ,IncoTerm ,PmtTerm ,Status
								,DischargePlace ,DeliveryPlace ,IntermodalVehicle ,CountryOfOrigin ,CountryDestination
								,UpdateSource ,Type ,OrderGroup ,Door ,Route ,Stop ,Notes ,EffectiveDate ,ContainerType
								,ContainerQty ,BilledContainerQty ,SOStatus ,MBOLKey ,InvoiceNo ,InvoiceAmount ,Salesman
								,GrossWeight ,Capacity ,PrintFlag ,LoadKey ,Rdd ,Notes2 ,SequenceNo ,Rds ,SectionKey
								,Facility ,PrintDocDate ,LabelPrice ,POKey ,ExternPOKey ,XDockFlag ,UserDefine01
								,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05 ,UserDefine06 ,UserDefine07
								,UserDefine08 ,UserDefine09 ,UserDefine10 ,Issued ,DeliveryNote ,PODCust ,PODArrive
								,PODReject ,PODUser ,xdockpokey ,SpecialHandling )  
							SELECT @c_NewOrderKey ,StorerKey ,ExternOrderKey ,OrderDate ,DeliveryDate ,Priority ,ConsigneeKey
								,C_contact1 ,C_Contact2 ,C_Company ,C_Address1 ,C_Address2 ,C_Address3 ,C_Address4
								,C_City ,C_State ,C_Zip ,C_Country ,C_ISOCntryCode ,C_Phone1 ,C_Phone2 ,C_Fax1
								,C_Fax2 ,C_vat ,BuyerPO ,BillToKey ,B_contact1 ,B_Contact2 ,B_Company ,B_Address1
								,B_Address2 ,B_Address3 ,B_Address4 ,B_City ,B_State ,B_Zip ,B_Country ,B_ISOCntryCode
								,B_Phone1 ,B_Phone2 ,B_Fax1 ,B_Fax2 ,B_Vat ,IncoTerm ,PmtTerm ,'0'
								,DischargePlace ,DeliveryPlace ,IntermodalVehicle ,CountryOfOrigin ,CountryDestination
								,UpdateSource ,Type ,OrderGroup ,Door ,Route ,Stop ,Notes ,EffectiveDate ,ContainerType
								,ContainerQty ,BilledContainerQty ,'0' , NULL MBOLKey ,InvoiceNo ,InvoiceAmount ,Salesman
								,GrossWeight ,Capacity ,PrintFlag ,NULL LoadKey ,Rdd ,Notes2 ,SequenceNo ,Rds ,SectionKey
								,Facility ,PrintDocDate ,LabelPrice ,POKey ,ExternPOKey ,XDockFlag ,UserDefine01
								,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05 ,UserDefine06 ,UserDefine07
								,UserDefine08 ,UserDefine09 ,UserDefine10 ,Issued ,DeliveryNote ,PODCust ,PODArrive
								,PODReject ,PODUser ,xdockpokey ,SpecialHandling
                     FROM  ORDERS WITH (NOLOCK)
    WHERE ORDERS.OrderKey = @c_OrderKey       
                     SET @n_err = @@ERROR      
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61865   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into Orders Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                        GOTO QUIT
                     END  
                  END 
                  -- Insert new Order Line 
                  IF @n_continue <> 3
                  BEGIN
                     -- transfer balance into new order line 
                     DECLARE C_TRF_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT ORDERLINENUMBER 
                        FROM   ORDERDETAIL WITH (NOLOCK)
                        WHERE  OrderKey = @c_OrderKey 
                        AND   (LoadKey = '' OR LoadKey IS NULL) 
                        AND    Status < '9' 
                     
                     OPEN C_TRF_DETAIL
                      
                     FETCH NEXT FROM C_TRF_DETAIL INTO @c_OrderLineNumber 
                     
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN 
                        UPDATE ORDERDETAIL WITH (ROWLOCK)
                           SET OrderKey = @c_NewOrderKey, 
                               OrderLineNumber =  @c_LineNo, 
                               EditDate = GETDATE(), -- KHLim01
                               TrafficCop = NULL
                        WHERE  OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber
                        SET @n_err = @@ERROR 
                        IF @n_err <> 0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61866   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                           SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into ORDERDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                           GOTO QUIT
                        END  
                        
                        UPDATE PICKDETAIL WITH (ROWLOCK)
                           SET OrderKey = @c_NewOrderKey, 
                               OrderLineNumber =  @c_LineNo, 
                               EditDate = GETDATE(), -- KHLim01
                               TrafficCop = NULL
                        WHERE  OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber
                        SET @n_err = @@ERROR 
                        IF @n_err <> 0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61867   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                           SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into ORDERDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                           GOTO QUIT
                        END           
                                       
                        SET @c_LineNo = RIGHT( '0000' + dbo.fnc_RTrim(CONVERT(char(5), (CONVERT(int, @c_LineNo) + 1))), 5) 
                        
                        FETCH NEXT FROM C_TRF_DETAIL INTO @c_OrderLineNumber
                     END -- While                         
                     CLOSE C_TRF_DETAIL
                     DEALLOCATE C_TRF_DETAIL

							-- Update ORDERS OpenQty & Status for OLD ORDER
							SELECT @n_TotalOpenQty = 0 , @c_NewStatus = ''
							SELECT @n_TotalOpenQty = ISNULL(SUM(OpenQty) , '0'),
									 @c_NewStatus = CASE WHEN SUM(OpenQty) = SUM(QtyAllocated)
															  	THEN '2'
															  	WHEN SUM(QtyAllocated) > 0
															  	THEN '1'
															  	ELSE '0'		END
							FROM ORDERDETAIL WITH (NOLOCK) 		
							WHERE  OrderKey = @c_OrderKey
					
					      UPDATE ORDERS WITH (ROWLOCK) 
					         SET Status = @c_NewStatus, 
									 OpenQty = @n_TotalOpenQty,
                            EditDate = GETDATE(), -- KHLim01
								    TrafficCop = NULL
					      WHERE OrderKey = @c_OrderKey 

                     SET @n_err = @@ERROR 
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61868   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Into ORDERS Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                        GOTO QUIT
                     END           

							-- Update ORDERS OpenQty & Status for New ORDER
							SELECT @n_TotalOpenQty = 0 , @c_NewStatus = ''
							SELECT @n_TotalOpenQty = ISNULL(SUM(OpenQty) , '0'),
									 @c_NewStatus = CASE WHEN SUM(OpenQty) = SUM(QtyAllocated)
															  	THEN '2'
															  	WHEN SUM(QtyAllocated) > 0
															  	THEN '1'
															  	ELSE '0'				END
							FROM ORDERDETAIL WITH (NOLOCK) 		
							WHERE  OrderKey = @c_NewOrderKey
					
					      UPDATE ORDERS WITH (ROWLOCK) 
					         SET Status = @c_NewStatus, 
									 OpenQty = @n_TotalOpenQty,
                            EditDate = GETDATE(), -- KHLim01
								    TrafficCop = NULL
					      WHERE OrderKey = @c_NewOrderKey 

                     SET @n_err = @@ERROR 
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61869   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Into ORDERS Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                        GOTO QUIT
                     END           
							-- Update ORDERS OpenQty & Status
			
                  END  
                  CLOSE ORDER_CUR
                  DEALLOCATE ORDER_CUR

                  -- Goto Declare cursor again 
                  GOTO START_BATCHPLANNING                                          
               END -- if found outstanding order lines
                
               -- Close Main Cursor
               CLOSE ORDER_CUR
               DEALLOCATE ORDER_CUR
               -- Cause New OrderKey not in the old cursor 
               -- Goto Declare cursor again 
               GOTO START_BATCHPLANNING                
            END
         END -- 4.0 Weight or Cube over truck capacity 

         
         FETCH NEXT FROM ORDER_CUR INTO 
            @c_OrderKey,          @c_Facility,           @c_Route,
            @n_StdCube,           @n_StdGrossWgt,        @c_ConsigneeKey,
            @c_Priority,          @d_DeliveryDate,       @d_OrderDate, 
            @c_ExternOrderKey,    @c_Company,            @c_Door,
            @c_RDD,               @c_OrderLineNumber,    @c_ExternLineNo,
            @c_SKU,               @c_OrderType,          @n_OpenQty,
            @n_QtyAllocated,      @c_TruckType,          @c_CarrierKey,  
            @n_TruckWeight,       @n_TruckCube,          @n_NoOfDrops, 
            @n_CaseCnt,           @n_Pallet,             @c_Status, 
            @n_OriginalQty              
      END -- Fetch While loop
      CLOSE ORDER_CUR
      DEALLOCATE ORDER_CUR 

      IF @n_Continue <> 3 
      BEGIN
         IF dbo.fnc_RTrim(@c_LoadKey) IS NOT NULL AND dbo.fnc_RTrim(@c_LoadKey) <> ''
         BEGIN
            SELECT @n_TotalOriginQty   = SUM(O.OriginalQty),
                   @n_TotalQtyAlloc    = SUM(O.QtyAllocated), 
                   @n_TotalCarton      = SUM(FLOOR(O.OriginalQty  / CASE WHEN P.CaseCnt > 0 THEN P.CaseCnt ELSE 1 END)),
                   @n_TotalAllocCarton = SUM(FLOOR(O.QtyAllocated / CASE WHEN P.CaseCnt > 0 THEN P.CaseCnt ELSE 1 END))
            FROM  ORDERDETAIL O WITH (NOLOCK)
            JOIN  SKU  S WITH (NOLOCK) ON S.StorerKey = O.StorerKey and S.SKU = O.SKU 
            JOIN  PACK P WITH (NOLOCK) ON P.PackKey = S.PackKey 
            WHERE O.LoadKey = @c_LoadKey
       
            IF @n_TotalOriginQty > @n_TotalQtyAlloc AND @n_TotalQtyAlloc > 0
            BEGIN
               UPDATE LoadPlan With (ROWLOCK)
               SET -- TrafficCop = NULL, --SOS# 85340
                   Status = '1', 
                   AllocatedCaseCnt = @n_TotalAllocCarton, 
                   CaseCnt   =  @n_TotalCarton
               WHERE LoadKey = @c_LoadKey    
               SET @n_err = @@ERROR      
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61871   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE LoadPlan Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                  GOTO QUIT
               END         
            END
            ELSE IF @n_TotalOriginQty = @n_TotalQtyAlloc
            BEGIN
               UPDATE LoadPlan With (ROWLOCK)
                 SET -- TrafficCop = NULL, --SOS# 85340
                     status     = '2', 
                     AllocatedCaseCnt = @n_TotalAllocCarton, 
                     CaseCnt          =  @n_TotalCarton
               WHERE LoadKey = @c_LoadKey
               SET @n_err = @@ERROR      
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61872   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE LoadPlan Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
                  GOTO QUIT
               END      
            END
         END 
      END 
   END -- If continue <> 3 -- START_BATCHPLANNING

   -- 8.0 Transfer all the Non fully allocated order to new orders
   DECLARE @c_PrevOrderKey NVARCHAR(10), 
           @c_PrevLoadKey  NVARCHAR(10) 
   
   SET @c_PrevOrderKey = ''
   
   If @b_debug = 1
   BEGIN
   	Print '8.0.0 >>>>>> Cleaning Remaining un-processed data'
   	SELECT LP.LoadKey, ORDERDETAIL.ORDERKEY, ORDERDETAIL.OrderLineNumber, ORDERDETAIL.SKU, 
   	       OpenQty, QtyAllocated 
   	FROM   ORDERDETAIL WITH (NOLOCK) 
   	JOIN   #LoadplanLog LP ON LP.OrderKey = ORDERDETAIL.OrderKey 
   	WHERE  ORDERDETAIL.QtyAllocated < ORDERDETAIL.OpenQty 
   	ORDER BY LP.LoadKey, ORDERDETAIL.ORDERKEY, ORDERDETAIL.OrderLineNumber   
   END
   
   DECLARE C_PartialAllocOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LP.LoadKey, ORDERDETAIL.ORDERKEY, ORDERDETAIL.OrderLineNumber, 
          OpenQty, QtyAllocated 
   FROM   ORDERDETAIL WITH (NOLOCK) 
   JOIN   #LoadplanLog LP ON LP.OrderKey = ORDERDETAIL.OrderKey 
   WHERE  ORDERDETAIL.QtyAllocated < ORDERDETAIL.OpenQty 
   ORDER BY LP.LoadKey, ORDERDETAIL.ORDERKEY, ORDERDETAIL.OrderLineNumber   
   
   OPEN C_PartialAllocOrders 
   
   FETCH NEXT FROM C_PartialAllocOrders INTO @c_LoadKey, @c_OrderKey, @c_OrderLineNumber, 
                                             @n_OpenQty, @n_QtyAllocated 
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      If @b_debug = 1
   	BEGIN
   		Print '8.0.1 >>>>>> Loadkey= ' +  dbo.fnc_RTrim(@c_LoadKey) + ' ;OrderKey= ' + dbo.fnc_RTrim(@c_OrderKey)
   		+ ' ;OrderLineNumber= ' + @c_OrderLineNumber + ' ;@n_OpenQty=' + CAST(@n_OpenQty AS CHAR) 
   		+  ';@n_QtyAllocated= ' + CAST(@n_QtyAllocated AS CHAR)
   	END
      IF @c_LoadKey <> @c_PrevLoadKey 
      BEGIN
         UPDATE LOADPLAN WITH (ROWLOCK)
            SET STATUS = '2' --, TrafficCop = NULL -- SOS# 85340
         WHERE LoadKey = @c_LoadKey 
   
         SET @c_PrevLoadKey = @c_LoadKey 
      END 
   
   	-- Update Only Need to Split A orderline with partially Allocated
   	-- Ignore those totally Not Allocated OrderDetail
   	IF @n_QtyAllocated > 0
   	BEGIN
   	   UPDATE ORDERDETAIL WITH (ROWLOCK)
   	      SET OpenQty      = @n_QtyAllocated,
   	          OriginalQty  = @n_QtyAllocated,
   	          Status       = '2', 
                EditDate   = GETDATE(), -- KHLim01
   	          TrafficCop = NULL
   	   WHERE  OrderKey = @c_OrderKey
   	   AND   OrderLineNumber = @c_OrderLineNumber
   	   SET @n_err = @@ERROR    
   	   IF @n_err <> 0  
   	   BEGIN  
   	      SELECT @n_continue = 3  
   	      SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61880   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
   	      SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update ORDERDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
   	      GOTO QUIT
   	   END  
   	END
   
      IF @c_OrderKey <> @c_PrevOrderKey 
      BEGIN 
   		SELECT @n_TotalOpenQty = SUM(QtyAllocated) FROM ORDERDETAIL WITH (NOLOCK) 		
   		WHERE  OrderKey = @c_OrderKey
   
         UPDATE ORDERS WITH (ROWLOCK) 
            SET Status = '2', 
   				 OpenQty = @n_TotalOpenQty,
                EditDate = GETDATE(), -- KHLim01
   			    TrafficCop = NULL
         WHERE OrderKey = @c_OrderKey 
         SET @n_err = @@ERROR      
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61881   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE ORDERS OpenQty Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
            GOTO QUIT
         END  
   
   		-- Update Prev New Order's OpenQty
         -- @c_NewOrderKey still refer to Previous NewOrderkey
   		SELECT @n_TotalOpenQty = SUM(OpenQty) FROM ORDERDETAIL WITH (NOLOCK) 		
   		WHERE  OrderKey = @c_NewOrderKey
   
   		If @b_debug = 1
   			PRINT '8.0.1a >> Update Previous Newly created Orders: ' + dbo.fnc_RTrim(@c_NewOrderKey) + ' Qty= ' + CAST(@n_TotalOpenQty AS CHAR)
   
         UPDATE ORDERS WITH (ROWLOCK) 
            SET OpenQty = @n_TotalOpenQty,
                EditDate = GETDATE(), -- KHLim01
   			    TrafficCop = NULL
         WHERE OrderKey = @c_NewOrderKey 
         SET @n_err = @@ERROR      
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61881   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE NEW ORDERS OpenQty Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
            GOTO QUIT
         END  
   
         UPDATE LoadPlanDetail WITH (ROWLOCK) 
            SET Status = '2', TrafficCop = NULL
               ,EditDate = GETDATE() -- KHLim01
         WHERE LoadKey = @c_LoadKey 
         AND   OrderKey = @c_OrderKey 
         SET @n_err = @@ERROR      
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61882   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE LoadPlanDetail Status Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
            GOTO QUIT
         END  
   
     SET @c_PrevOrderKey = @c_OrderKey
         
         -- Get New OrderKey  
         SELECT @b_Success = 1  
      
         EXECUTE nspg_getkey  
            'ORDER'  
            , 10  
            , @c_NewOrderKey OUTPUT  
            , @b_Success OUTPUT  
            , @n_err OUTPUT  
            , @c_ErrMsg OUTPUT  
         IF NOT @b_Success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END                   
         ELSE
         BEGIN
            IF @b_debug = 1
            BEGIN
               Print '8.0.2 >>>>>> Insert Orders : ' +  dbo.fnc_RTrim(@c_NewOrderKey) + ' FROM ' + dbo.fnc_RTrim(@c_OrderKey)
   				SELECT @c_NewOrderKey ,@c_LineNo ,ExternLineNo ,Sku ,StorerKey 
   					,(@n_OpenQty - @n_QtyAllocated) NewOpenQty , OpenQty
   					,0 NewQtyAllocated ,QtyAllocated 
   		         ,CASE WHEN @n_QtyAllocated = 0 THEN '0'
   		               WHEN @n_OpenQty = @n_QtyAllocated THEN '2' 
   		               WHEN @n_OpenQty < @n_QtyAllocated THEN '1' 
   		               ELSE '0' 
   		          END AS Status 
   		      FROM ORDERDETAIL WITH (NOLOCK)
   		      WHERE OrderKey = @c_OrderKey
            END
      
            SELECT @c_LineNo = dbo.fnc_RTrim('00001')
            SELECT @c_LineNo = RIGHT(@c_LineNo, 5)
            -- Create New Order 
   
            INSERT INTO ORDERS
   				(OrderKey ,StorerKey ,ExternOrderKey ,OrderDate ,DeliveryDate ,Priority ,ConsigneeKey
   				,C_contact1 ,C_Contact2 ,C_Company ,C_Address1 ,C_Address2 ,C_Address3 ,C_Address4
   				,C_City ,C_State ,C_Zip ,C_Country ,C_ISOCntryCode ,C_Phone1 ,C_Phone2 ,C_Fax1
   				,C_Fax2 ,C_vat ,BuyerPO ,BillToKey ,B_contact1 ,B_Contact2 ,B_Company ,B_Address1
   				,B_Address2 ,B_Address3 ,B_Address4 ,B_City ,B_State ,B_Zip ,B_Country ,B_ISOCntryCode
   				,B_Phone1 ,B_Phone2 ,B_Fax1 ,B_Fax2 ,B_Vat ,IncoTerm ,PmtTerm ,Status
   				,DischargePlace ,DeliveryPlace ,IntermodalVehicle ,CountryOfOrigin ,CountryDestination
   				,UpdateSource ,Type ,OrderGroup ,Door ,Route ,Stop ,Notes ,EffectiveDate ,ContainerType
   				,ContainerQty ,BilledContainerQty ,SOStatus ,MBOLKey ,InvoiceNo ,InvoiceAmount ,Salesman
   				,GrossWeight ,Capacity ,PrintFlag ,LoadKey ,Rdd ,Notes2 ,SequenceNo ,Rds ,SectionKey
   				,Facility ,PrintDocDate ,LabelPrice ,POKey ,ExternPOKey ,XDockFlag ,UserDefine01
   				,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05 ,UserDefine06 ,UserDefine07
   				,UserDefine08 ,UserDefine09 ,UserDefine10 ,Issued ,DeliveryNote ,PODCust ,PODArrive
   				,PODReject ,PODUser ,xdockpokey ,SpecialHandling)  
   			SELECT @c_NewOrderKey ,StorerKey ,ExternOrderKey ,OrderDate ,DeliveryDate ,Priority ,ConsigneeKey
   				,C_contact1 ,C_Contact2 ,C_Company ,C_Address1 ,C_Address2 ,C_Address3 ,C_Address4
   				,C_City ,C_State ,C_Zip ,C_Country ,C_ISOCntryCode ,C_Phone1 ,C_Phone2 ,C_Fax1
   				,C_Fax2 ,C_vat ,BuyerPO ,BillToKey ,B_contact1 ,B_Contact2 ,B_Company ,B_Address1
   				,B_Address2 ,B_Address3 ,B_Address4 ,B_City ,B_State ,B_Zip ,B_Country ,B_ISOCntryCode
   				,B_Phone1 ,B_Phone2 ,B_Fax1 ,B_Fax2 ,B_Vat ,IncoTerm ,PmtTerm ,'0'
   				,DischargePlace ,DeliveryPlace ,IntermodalVehicle ,CountryOfOrigin ,CountryDestination
   				,UpdateSource ,Type ,OrderGroup ,Door ,Route ,Stop ,Notes ,EffectiveDate ,ContainerType
   				,ContainerQty ,BilledContainerQty ,'0' , NULL MBOLKey ,InvoiceNo ,InvoiceAmount ,Salesman
   				,GrossWeight ,Capacity ,PrintFlag ,NULL LoadKey ,Rdd ,Notes2 ,SequenceNo ,Rds ,SectionKey
   				,Facility ,PrintDocDate ,LabelPrice ,POKey ,ExternPOKey ,XDockFlag ,UserDefine01
   				,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05 ,UserDefine06 ,UserDefine07
   				,UserDefine08 ,UserDefine09 ,UserDefine10 ,Issued ,DeliveryNote ,PODCust ,PODArrive
   				,PODReject ,PODUser ,xdockpokey ,SpecialHandling
            FROM  ORDERS WITH (NOLOCK)
            WHERE ORDERS.OrderKey = @c_OrderKey       
            SET @n_err = @@ERROR      
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61883   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into Orders Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
               GOTO QUIT
            END  
         END -- @b_Success = 1  
      END -- -- If @c_OrderKey <> @c_PrevOrderKey                                   
      -- Insert new Order Line 
      IF @n_continue <> 3
      BEGIN
   		If @b_debug = 2
   		BEGIN
            Print '8.0.3 >>>>>> Insert OrderDetail : ' +  dbo.fnc_RTrim(@c_NewOrderKey) + ' FROM ' + dbo.fnc_RTrim(@c_OrderKey)
   			SELECT @c_NewOrderKey ,@c_LineNo ,ExternOrderKey ,ExternLineNo 
   				,Sku ,StorerKey ,(@n_OpenQty - @n_QtyAllocated) NewOpenQty, OpenQty , OriginalQty
   				,0 NewQtyAllocated , @n_QtyAllocated QtyAllocated
   	         ,CASE WHEN @n_QtyAllocated = 0 THEN '0'
   	               WHEN @n_OpenQty = @n_QtyAllocated THEN '2' 
   	               WHEN @n_OpenQty < @n_QtyAllocated THEN '1' 
   	               ELSE '0' 
   	          END AS NewStatus , Status
   	      FROM ORDERDETAIL WITH (NOLOCK)
   	      WHERE OrderKey = @c_OrderKey
   	      AND   OrderLineNumber = @c_OrderLineNumber
   		END
   
   		-- Update to New Orderkey for those totally Not Allocated OrderDetail
   		IF @n_QtyAllocated = 0
   		BEGIN
   			if @b_debug = 1
   			BEGIN
   				SELECT 'Old Orders' 'Before' ,Orderkey ,OpenQty FROM ORDERS (NOLOCK)
   		      WHERE OrderKey = @c_OrderKey
   				UNION
   				SELECT 'New Orders' 'Before' ,Orderkey ,OpenQty FROM ORDERS (NOLOCK)
   		      WHERE OrderKey = @c_NewOrderKey
   
   				SELECT 'Before...' ORDERDETAIL, SKU , OpenQty , QtyAllocated FROM ORDERDETAIL (NOLOCK)
   		      WHERE OrderKey = @c_OrderKey
   		      AND   OrderLineNumber = @c_OrderLineNumber
   
   			END
   				
   			UPDATE ORDERDETAIL 
   				SET OrderKey = @c_NewOrderKey,
   					 OrderLineNumber = @c_LineNo,
                   EditDate = GETDATE(), -- KHLim01
   					 Trafficcop = NULL
   	      WHERE OrderKey = @c_OrderKey
   	      AND   OrderLineNumber = @c_OrderLineNumber
   	      SET @n_err = @@ERROR 
   	      IF @n_err <> 0  
   	      BEGIN  
   	         SELECT @n_continue = 3  
   	         SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61884   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
   	         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Transfer to NEW ORDERDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
   	         GOTO QUIT
   	      END  				
   
   			if @b_debug = 1
   			BEGIN
   				SELECT 'Old ORDERS' 'After' ,Orderkey ,OpenQty FROM ORDERS (NOLOCK)
   		      WHERE OrderKey = @c_OrderKey
   				UNION
   				SELECT 'NewORDERS ' 'After'  ,Orderkey ,OpenQty FROM ORDERS (NOLOCK)
   		      WHERE OrderKey = @c_NewOrderKey
   
   				SELECT 'After...' newORDERDETAIL, SKU , OpenQty , QtyAllocated FROM ORDERDETAIL (NOLOCK)
   		      WHERE OrderKey = @c_NewOrderKey
   		      AND   OrderLineNumber = @c_LineNo
   
   			END
   
   		END
   		ELSE
   		-- @n_QtyAllocated > 0 
   		BEGIN		-- Update Only Need to Split A orderline with partially Allocated
   	      -- transfer balance into new order line 
				/*CS01 Start*/
   	      INSERT INTO ORDERDETAIL 
   				(OrderKey ,OrderLineNumber ,ExternOrderKey ,ExternLineNo 
   				,Sku ,StorerKey ,ManufacturerSku ,RetailSku ,AltSku ,OpenQty
   				,ShippedQty ,AdjustedQty ,QtyPreAllocated ,QtyAllocated ,QtyPicked ,UOM
   				,PackKey ,PickCode ,CartonGroup ,Lot ,ID ,Facility ,Status
   				,UnitPrice ,Tax01 ,Tax02 ,ExtendedPrice ,UpdateSource ,Lottable01 ,Lottable02
   				,Lottable03 ,Lottable04 ,Lottable05 , Lottable06 ,Lottable07
   				,Lottable08 ,Lottable09 ,Lottable10 , Lottable11 ,Lottable12
   				,Lottable13 ,Lottable14 ,Lottable15 ,EffectiveDate ,TariffKey ,FreeGoodQty
   				,GrossWeight ,Capacity ,LoadKey ,MBOLKey ,QtyToProcess ,MinShelfLife
   				,UserDefine01 ,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05
   				,UserDefine06 ,UserDefine07 ,UserDefine08 ,UserDefine09
   				,POkey ,ExternPOKey)
   			SELECT @c_NewOrderKey ,@c_LineNo ,ExternOrderKey ,ExternLineNo 
   				,Sku ,StorerKey ,ManufacturerSku ,RetailSku ,AltSku ,(@n_OpenQty - @n_QtyAllocated)
   				,0 ShippedQty ,0 AdjustedQty ,0 QtyPreAllocated ,0 QtyAllocated ,0 QtyPicked ,UOM
   				,PackKey ,PickCode ,CartonGroup ,Lot ,ID ,Facility 
   	         ,CASE WHEN @n_QtyAllocated = 0 THEN '0'
   	               WHEN @n_OpenQty = @n_QtyAllocated THEN '2' 
   	               WHEN @n_OpenQty < @n_QtyAllocated THEN '1' 
   	               ELSE '0' 
   	          END AS Status 
   				,UnitPrice ,Tax01 ,Tax02 ,ExtendedPrice ,UpdateSource ,Lottable01 ,Lottable02
   				,Lottable03 ,Lottable04 ,Lottable05 , Lottable06 ,Lottable07
   				,Lottable08 ,Lottable09 ,Lottable10 , Lottable11 ,Lottable12
   				,Lottable13 ,Lottable14 ,Lottable15 ,EffectiveDate ,TariffKey , 0 FreeGoodQty
   				,GrossWeight ,Capacity ,NULL LoadKey ,NULL MBOLKey ,0 QtyToProcess ,MinShelfLife
   				,UserDefine01 ,UserDefine02 ,UserDefine03 ,UserDefine04 ,UserDefine05
   				,UserDefine06 ,UserDefine07 ,UserDefine08 ,UserDefine09
   				,POkey ,ExternPOKey
   	      FROM ORDERDETAIL WITH (NOLOCK)
   	      WHERE OrderKey = @c_OrderKey
   	      AND   OrderLineNumber = @c_OrderLineNumber
				/*CS01 End*/
   	      SET @n_err = @@ERROR 
   	      IF @n_err <> 0  
   	      BEGIN  
   	         SELECT @n_continue = 3  
   	         SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61885   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
   	         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into ORDERDETAIL Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
   	         GOTO QUIT
   	      END  
   		END -- 	@n_QtyAllocated > 0
   		SET @c_LineNo = RIGHT( '0000' + dbo.fnc_RTrim(CONVERT(char(5), (CONVERT(int, @c_LineNo) + 1))), 5)
   
      END         
      FETCH NEXT FROM C_PartialAllocOrders INTO @c_LoadKey, @c_OrderKey, @c_OrderLineNumber, 
                                                @n_OpenQty, @n_QtyAllocated 
   END -- While fetch status
   CLOSE C_PartialAllocOrders
   DEALLOCATE C_PartialAllocOrders   
   
   IF @n_continue <> 3 
   BEGIN
   	-- Update Prev New Order's OpenQty
      -- @c_NewOrderKey still refer to Previous NewOrderkey
   	SELECT @n_TotalOpenQty = SUM(OpenQty) FROM ORDERDETAIL WITH (NOLOCK) 		
   	WHERE  OrderKey = @c_NewOrderKey
   
   	If @b_debug = 1
   	BEGIN
   		PRINT 'Update Last Newly created Orders: ' + dbo.fnc_RTrim(@c_NewOrderKey) + ' Qty= ' + CAST(@n_TotalOpenQty AS CHAR)
   		SELECT Orderkey ,SKU ,OpenQty FROM ORDERDETAIL WITH (NOLOCK) 		
   		WHERE  OrderKey = @c_NewOrderKey
   	END
   
      UPDATE ORDERS WITH (ROWLOCK) 
         SET OpenQty = @n_TotalOpenQty,
             EditDate = GETDATE(), -- KHLim01
   		    TrafficCop = NULL
      WHERE OrderKey = @c_NewOrderKey 
      SET @n_err = @@ERROR      
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=61881   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Final UPDATE NEW ORDERS OpenQty Failed. (nsp_BatchPlanning_AllocQty)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '  
         GOTO QUIT
      END  
   END
   
QUIT:
   /* #INCLUDE <SPPREOP2.SQL> */
   IF @n_continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_success = 0
      ROLLBACK TRAN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_BatchPlanning_AllocQty'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

END -- Procedure

SET QUOTED_IDENTIFIER OFF 

GO