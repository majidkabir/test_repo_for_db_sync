SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Object Name: isp_loadplan_sheet_trade_ret                               */
/* Modification History:                                                   */
/*                                                                         */
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/***************************************************************************/
CREATE PROC [dbo].[isp_loadplan_sheet_trade_ret] (@c_loadkey nvarchar(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @c_delivery_zone nvarchar(10),
           @c_load_userdef1 nvarchar(200),
           @n_ordercnt int,
           @d_adddate datetime,
           @c_trucksize nvarchar(10),
           @c_storerkey nvarchar(15),
           @c_orderkey nvarchar(15),
           @c_type nvarchar(10),
           @c_company nvarchar(45),
           @c_teamleader nvarchar(255),
           @c_driver nvarchar(255),
           @c_deliveryman nvarchar(255),
           @c_vehicle nvarchar(255),
           @c_descr nvarchar(40),
           @c_pmtterm nvarchar(10),
           @c_load_userdef2 nvarchar(200),
           @c_externOrderkey nvarchar(30),
           @n_drop int,
           @n_cube float,
           @n_weight float
   CREATE TABLE #result (
      loadkey nvarchar(10),
      adddate datetime NULL,
      teamleader nvarchar(255) NULL,
      deliveryman nvarchar(255) NULL,
      trucksize nvarchar(10) NULL,
      vehicle nvarchar(255) NULL,
      driver nvarchar(255) NULL,
      deliveryarea nvarchar(10) NULL,
      remark nvarchar(200) NULL,
      ordercnt int NULL,
      storerkey nvarchar(15) NULL,
      company nvarchar(45) NULL,
      remark2 nvarchar(200) NULL,
      dropcnt int NULL,
      cube float,
      weight float
   )
   DELETE FROM ids_lp_nested_orderkey
   DECLARE cur1 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
      LOADPLANRETDETAIL.loadkey,
      LOADPLAN.delivery_zone,
      CONVERT(nvarchar(200), LOADPLAN.load_userdef1),
      LOADPLAN.ordercnt,
      LOADPLAN.lpuserdefdate01,
      LOADPLAN.trucksize,
      RECEIPT.storerkey,
      STORER.company,
      CONVERT(nvarchar(200), LOADPLAN.load_userdef2),
      cube = (SELECT
         SUM(LOADPLANRETDETAIL.cube)
      FROM loadplanretdetail(nolock)
      WHERE loadplanretdetail.loadkey = @c_loadkey),
      weight = (SELECT
         SUM(LOADPLANRETDETAIL.weight)
      FROM loadplanretdetail(nolock)
      WHERE loadplanretdetail.loadkey = @c_loadkey)
   FROM LOADPLAN(nolock)
   JOIN LOADPLANRETDETAIL(nolock)
      ON LOADPLAN.LoadKey = LOADPLANRETDETAIL.LoadKey
   JOIN RECEIPT(nolock)
      ON LOADPLANRETDETAIL.Loadkey = RECEIPT.Loadkey
   JOIN STORER(nolock)
      ON RECEIPT.storerkey = STORER.storerkey
   WHERE LOADPLAN.loadkey = @c_loadkey
   GROUP BY LOADPLANRETDETAIL.loadkey,
            LOADPLAN.delivery_zone,
            CONVERT(nvarchar(200), LOADPLAN.load_userdef1),
            LOADPLAN.ordercnt,
            LOADPLAN.lpuserdefdate01,
            LOADPLAN.trucksize,
            RECEIPT.storerkey,
            STORER.company,
            CONVERT(nvarchar(200), LOADPLAN.load_userdef2)
   OPEN cur1
   FETCH NEXT FROM cur1 INTO @c_loadkey, @c_delivery_zone, @c_load_userdef1, @n_ordercnt, @d_adddate, @c_trucksize,
   @c_storerkey, @c_company, @c_load_userdef2, @n_cube, @n_weight
   SELECT
      @n_drop = COUNT(DISTINCT consigneekey)
   FROM ORDERS(NOLOCK)
   WHERE loadkey = @c_loadkey
   WHILE (@@fetch_status = 0)
   BEGIN
      INSERT INTO #result
         VALUES (@c_loadkey, @d_adddate, @c_teamleader, @c_deliveryman, @c_trucksize, @c_vehicle, @c_driver, @c_delivery_zone, 
                 @c_load_userdef1, @n_ordercnt, @c_storerkey, @c_company, @c_load_userdef2, @n_drop, @n_cube, @n_weight)
      FETCH NEXT FROM cur1 INTO @c_loadkey, @c_delivery_zone, @c_load_userdef1, @n_ordercnt, @d_adddate, @c_trucksize,
      @c_storerkey, @c_company, @c_load_userdef2, @n_cube, @n_weight
   END
   CLOSE cur1
   DEALLOCATE cur1
   --    Cur2 - to get team leader    
   DECLARE cur2 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT
      CODELKUP.description
   FROM IDS_LP_DRIVER(nolock)
   JOIN CODELKUP(nolock)
      ON IDS_LP_DRIVER.drivercode = CODELKUP.code
   WHERE IDS_LP_DRIVER.loadkey = @c_loadkey
   AND CODELKUP.listname = 'Driver'
   AND CODELKUP.short = 'TL'
   AND CODELKUP.long = 'Team Leader'
   OPEN cur2
   FETCH NEXT FROM cur2 INTO @c_descr
   WHILE (@@fetch_status = 0)
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_teamleader)) <> ''
         SELECT
            @c_teamleader = @c_teamleader + ' / '
      SET @c_teamleader = @c_teamleader + dbo.fnc_RTrim(@c_descr) -- + ' / '    
      FETCH NEXT FROM cur2 INTO @c_descr
   END
   CLOSE cur2
   DEALLOCATE cur2
   UPDATE #result
   SET teamleader = @c_teamleader
   --substring(@c_teamleader,1,len(@c_teamleader)-3)    
   --    End of getting team leader    
   --    Cur3 - to get delivery man    
   DECLARE cur3 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT
      dbo.fnc_LTrim(dbo.fnc_RTrim(CODELKUP.description))
   FROM IDS_LP_DRIVER(nolock)
   JOIN CODELKUP(nolock)
      ON IDS_LP_DRIVER.drivercode = CODELKUP.code
   WHERE IDS_LP_DRIVER.loadkey = @c_loadkey
   AND CODELKUP.listname = 'Driver'
   AND CODELKUP.short = 'DM'
   AND CODELKUP.long = 'Delivery Man'
   OPEN cur3
   FETCH NEXT FROM cur3 INTO @c_descr
   WHILE (@@fetch_status = 0)
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_deliveryman)) <> ''
         SELECT
            @c_deliveryman = @c_deliveryman + ' / '
      SET @c_deliveryman = @c_deliveryman + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_descr)) -- + ' / '
      FETCH NEXT FROM cur3 INTO @c_descr
   END
   CLOSE cur3
   DEALLOCATE cur3
   UPDATE #result
   SET deliveryman = @c_deliveryman
   --substring(@c_deliveryman,1,len(@c_deliveryman)-3)    
   --    End of getting delivery man    
   --    Cur4 - to get driver    
   DECLARE cur4 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT
      dbo.fnc_LTrim(dbo.fnc_RTrim(CODELKUP.description))
   FROM IDS_LP_DRIVER(nolock)
   JOIN CODELKUP(nolock)
      ON IDS_LP_DRIVER.drivercode = CODELKUP.code
   WHERE IDS_LP_DRIVER.loadkey = @c_loadkey
   AND CODELKUP.listname = 'Driver'
   AND CODELKUP.short = 'DR'
   AND CODELKUP.long = 'Driver'
   OPEN cur4
   FETCH NEXT FROM cur4 INTO @c_descr
   WHILE (@@fetch_status = 0)
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_driver)) <> ''
         SELECT
            @c_driver = @c_driver + ' / '
      SET @c_driver = @c_driver + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_descr)) -- + ' / '
      FETCH NEXT FROM cur4 INTO @c_descr
   END
   CLOSE cur4
   DEALLOCATE cur4
   UPDATE #result
   SET driver = @c_driver -- substring(@c_driver,1,len(@c_driver)-3)    
   -- 	End of getting driver    
   DECLARE cur5 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(vehiclenumber))
   FROM ids_lp_vehicle(nolock)
   WHERE loadkey = @c_loadkey
   ORDER BY linenumber
   OPEN cur5
   FETCH NEXT FROM cur5 INTO @c_descr
   WHILE (@@fetch_status = 0)
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehicle)) <> ''
         SELECT
            @c_vehicle = @c_vehicle + ' / '
      SET @c_vehicle = @c_vehicle + dbo.fnc_RTrim(@c_descr) -- + ' / '    
      FETCH NEXT FROM cur5 INTO @c_descr
   END
   CLOSE cur5
   DEALLOCATE cur5
   UPDATE #result
   SET vehicle = '*' + @c_vehicle -- substring(@c_vehicle,1,len(@c_vehicle)-3)    
   SELECT
      CONVERT(nvarchar(30), SUSER_SNAME()) 'user_name',
      *
   FROM #result
   -- select * From #result  
   DROP TABLE #result
   SET NOCOUNT OFF
END

GO