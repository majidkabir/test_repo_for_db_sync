SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_loadplan_manifest_discrete                     */
/* Creation Date:  25-Sept-2003                                         */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Report                                                      */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - (Loadplan Number)                   */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 22-Oct-2012  Shong     Allow the AddDate With NULL                   */
/* 22-Feb-2017  CSCHONG   Add new field (CS01)                          */ 
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/************************************************************************/
CREATE PROC [dbo].[isp_loadplan_manifest_discrete](@c_loadkey NVARCHAR(10))  
AS  
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	  
	DECLARE @c_teamleader     NVARCHAR(255),
	        @c_description    NVARCHAR(255),
	        @c_deliveryman    NVARCHAR(255),
	        @c_driver         NVARCHAR(255),
	        @c_short          NVARCHAR(18),
	        @c_long           NVARCHAR(250),
	        @c_vehiclenumber  NVARCHAR(10),
	        @c_vehiclenos     NVARCHAR(255),
	        @n_discrete       INT,
	        @n_vehiclecnt     INT  
	
	CREATE TABLE #result
	(
		loadkey         NVARCHAR(10),
		orderkey        NVARCHAR(10),
		externorderkey  NVARCHAR(50)     NULL,  --tlting_ext
		allocated       NVARCHAR(1)      NULL,
		adddate         DATETIME	   NULL,
		teamleader      NVARCHAR(255) NULL,
		deliveryman     NVARCHAR(255) NULL,
		vehicle         NVARCHAR(255) NULL,
		vehicletype     NVARCHAR(20) 		 NULL,
		vehiclecnt      INT 				 NULL,
		driver          NVARCHAR(255) NULL,
		trucksize       NVARCHAR(10) NULL,
		trfroom         NVARCHAR(10) NULL,	-- Modified by YokeBeen on 07-Oct-2002 (SOS# 7632)  
		delivery_zone   NVARCHAR(10) NULL,
		remark          NVARCHAR(16) NULL,
		sku             NVARCHAR(20) NULL,
		descr           NVARCHAR(60) NULL,
		itemclass       NVARCHAR(250) NULL,
		packkey         NVARCHAR(10) NULL,
		pack_casecnt    INT NULL,
		capacity        FLOAT(8) NULL,
		grossweight     FLOAT(8) NULL,
		totalqty        INT NULL,
		total_ctn       INT NULL,
		total_pc        INT NULL,
		username        NVARCHAR(255) NULL,
		pack_Innerpack  INT NULL,
		total_inner     INT NULL,
		packdescr       NVARCHAR(45) NULL,
		ExtLoadKey      NVARCHAR(30) NULL                 --CS01
	)  
	
	INSERT INTO #result
	  (
	    loadkey,
	    orderkey,
	    externorderkey,
	    allocated,
	    adddate,
	    trucksize,
	    trfroom,
	    delivery_zone,
	    remark,
	    sku,
	    descr,
	    itemclass,
	    packkey,
	    pack_casecnt,
	    capacity,
	    grossweight,
	    totalqty,
	    username,
	    pack_innerpack,
	    packdescr,
	    ExtLoadKey                       --CS01
	  )
	SELECT LoadPlan.LoadKey,
	       Orders.Orderkey,
	       Orders.ExternOrderkey,
	       Orders.UserDefine08,
	       LoadPlan.lpuserdefdate01,
	       LoadPlan.TruckSize,
	       LoadPlan.TrfRoom,
	       LoadPlan.Delivery_Zone,
	       remark = CONVERT(CHAR(255), LoadPlan.Load_UserDef1),
	       ORDERDETAIL.Sku,
	       SKU.DESCR,
	       Codelkup.Description,
	       PACK.Packkey,
	       p_casecnt = PACK.CaseCnt,
	       SKU.StdCube,
	       SKU.stdgrosswgt,
	       qty = SUM(
	           ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty
	       ),
	       username = SUSER_SNAME(),
	       PACK.Innerpack,
	       PACK.Packdescr,
	       LoadPlan.ExternLoadKey                    --CS01
	FROM   LoadPlan (NOLOCK),
	       ORDERDETAIL(NOLOCK),
	       ORDERS(NOLOCK),
	       PACK(NOLOCK),
	       SKU(NOLOCK),
	       CODELKUP(NOLOCK)
	WHERE  (LoadPlan.LoadKey = ORDERS.LoadKey)
	       AND (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
	       AND (ORDERDETAIL.Sku = SKU.Sku)
	       AND (ORDERDETAIL.StorerKey = SKU.StorerKey)
	       AND (ORDERDETAIL.PackKey = PACK.PackKey)
	       AND (SKU.itemclass = Codelkup.Code)
	       AND (Codelkup.listname = 'ITEMCLASS')
	       AND (ORDERS.UserDefine08 = 'Y')
	       AND (LOADPLAN.LoadKey = @c_loadkey)
	GROUP BY
	       LoadPlan.LoadKey,
	       Orders.Orderkey,
	       Orders.ExternOrderkey,
	       Orders.UserDefine08,
	       LoadPlan.lpuserdefdate01,
	       LoadPlan.TruckSize,
	       LoadPlan.TrfRoom,
	       LoadPlan.Delivery_Zone,
	       CONVERT(CHAR(255), LoadPlan.Load_UserDef1),
	       ORDERDETAIL.Sku,
	       SKU.DESCR,
	       Codelkup.Description,
	       PACK.Packkey,
	       PACK.CaseCnt,
	       SKU.StdCube,
	       SKU.stdgrosswgt,
	       PACK.InnerPack,
	       PACK.Packdescr
	       ,LoadPlan.ExternLoadKey                     --CS01 
	
	
	/*  
	update #result  
	set total_ctn = 0, total_inner = 0, total_pc = totalqty  
	where pack_casecnt = 0 and pack_innerpack = 0  
	
	update #result  
	set total_ctn = 0,  
	total_inner = floor(totalqty/pack_innerpack),  
	total_pc = totalqty % cast(pack_innerpack as int)  
	where pack_casecnt = 0 and pack_innerpack > 0 and  
	totalqty >= pack_innerpack  
	*/  
	
	UPDATE #result
	SET    total_ctn = CASE 
	                        WHEN pack_casecnt = 0 THEN 0
	                        ELSE FLOOR(totalqty / pack_casecnt)
	                   END,
	       total_inner = CASE 
	                          WHEN pack_innerpack = 0 THEN 0
	                          WHEN pack_innerpack > 0 AND pack_casecnt = 0 THEN 
	                               FLOOR(totalqty / pack_innerpack)
	                          ELSE FLOOR((totalqty % CAST(pack_casecnt AS INT)) / pack_innerpack)
	                     END,
	       total_pc = 0  
	
	UPDATE #result
	SET    total_pc = totalqty -(total_ctn * pack_casecnt) -(total_inner * pack_innerpack) 
	
	
	/*  
	update #result  
	set total_ctn = floor(totalqty/pack_casecnt),  
	total_inner = floor((totalqty% cast(pack_casecnt as Int))/pack_innerpack),  
	total_pc = totalqty - floor(totalqty/pack_casecnt) - floor((totalqty% cast(pack_casecnt as Int))/pack_innerpack)  
	where totalqty >= pack_casecnt and  
	pack_casecnt > 0  
	*/ 
	/*  
	update #result  
	set total_ctn = 0, total_inner = 0, total_pc = totalqty  
	where totalqty < pack_innerpack and totalqty < pack_casecnt and  
	(pack_innerpack > 0 or pack_casecnt > 0)  
	*/ 
	
	/*Start - Get drivers (team leader, deliver man, and driver) from codelkup table */  
	DECLARE cur1 CURSOR LOCAL FAST_FORWARD READ_ONLY 
	FOR
	    SELECT b.description,
	           b.short,
	           b.long
	    FROM   ids_lp_driver a(NOLOCK),
	           codelkup b(NOLOCK)
	    WHERE  a.drivercode = b.code
	           AND b.listname = 'Driver'
	           AND b.short IN ('TL', 'DM', 'DR')
	           AND b.long IN ('Team Leader', 'Delivery Man', 'Driver')
	           AND a.loadkey = @c_loadkey 
	
	OPEN cur1 
	
	FETCH NEXT FROM cur1 INTO @c_description, @c_short, @c_long  
	
	WHILE (@@fetch_status = 0)
	BEGIN
	    IF dbo.fnc_RTrim(@c_short) = 'TL'
	       AND dbo.fnc_RTrim(@c_long) = 'Team Leader'
	    BEGIN
	        SET @c_teamleader = @c_teamleader + dbo.fnc_RTrim(@c_description) + 
	            ' / '
	    END
	    ELSE 
	    IF dbo.fnc_RTrim(@c_short) = 'DM'
	       AND dbo.fnc_RTrim(@c_long) = 'Delivery Man'
	    BEGIN
	        SET @c_deliveryman = @c_deliveryman + dbo.fnc_RTrim(@c_description) 
	            + ' / '
	    END
	    ELSE 
	    IF dbo.fnc_RTrim(@c_short) = 'DR'
	       AND dbo.fnc_RTrim(@c_long) = 'Driver'
	    BEGIN
	        SET @c_driver = @c_driver + dbo.fnc_RTrim(@c_description) + ' / '
	    END
	    
	    FETCH NEXT FROM cur1 INTO @c_description, @c_short, @c_long
	END 
	
	CLOSE cur1 
	DEALLOCATE cur1  
	
	UPDATE #result
	SET    teamleader = @c_teamleader  
	
	UPDATE #result
	SET    deliveryman = @c_deliveryman  
	
	
	UPDATE #result
	SET    driver = @c_driver 
	/*End - Get drivers (team leader, deliver man, and driver) from codelkup table */ 
	
	-- start: get vehicle numbers  
	DECLARE cur2 CURSOR LOCAL FAST_FORWARD READ_ONLY 
	FOR
	    SELECT a.vehiclenumber
	    FROM   ids_lp_vehicle a(NOLOCK),
	           ids_vehicle b(NOLOCK)
	    WHERE  a.loadkey = @c_loadkey
	           AND a.vehiclenumber = b.vehiclenumber
	    ORDER BY
	           linenumber 
	
	OPEN cur2  
	
	SELECT @n_vehiclecnt = 0 
	FETCH NEXT FROM cur2 INTO @c_vehiclenumber  
	
	WHILE (@@fetch_status = 0)
	BEGIN
	    SELECT @n_vehiclecnt = @n_vehiclecnt + 1  
	    IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehiclenos)) <> ''
	        SELECT @c_vehiclenos = @c_vehiclenos + ' / '  
	    
	    SET @c_vehiclenos = @c_vehiclenos + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehiclenumber)) -- + ' / '  
	    
	    FETCH NEXT FROM cur2 INTO @c_vehiclenumber
	END 
	
	CLOSE cur2 
	DEALLOCATE cur2 
	-- end: get vehicle numbers  
	
	UPDATE #result
	SET    vehicle = '*' + @c_vehiclenos,
	       vehiclecnt = @n_vehiclecnt 
	
	-- start: get the major vehicle type  
	UPDATE #result
	SET    vehicletype = b.vehicletype
	FROM   ids_lp_vehicle a(NOLOCK),
	       ids_vehicle b(NOLOCK)
	WHERE  a.loadkey = @c_loadkey
	       AND a.vehiclenumber = b.vehiclenumber
	       AND a.linenumber = '00001' 
	-- end: get the major vehicle type  
	
	-- get the no of discrete orders  
	SELECT @n_discrete = COUNT(*)
	FROM   orders(NOLOCK),
	       loadplan(NOLOCK)
	WHERE  orders.loadkey = loadplan.loadkey
	       AND dbo.fnc_RTrim(orders.userdefine08) = 'Y'
	       AND loadplan.loadkey = @c_loadkey  
	
	SELECT *,
	       @n_discrete
	FROM   #result 
	
	DROP TABLE #result
END -- end of procedure  

GO