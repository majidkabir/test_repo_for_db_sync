SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_loadplan_sheet                                         */
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
/* 06-Jun-2002  SHONG     1.1   There is a business requirement for the    */
/*                              Load Plan Sheet to page break by facility  */
/*                              so that the report can be split to the     */
/*                              different facilities for physical release. */
/* 27-Mar-2008  Leong     1.2   SOS 102426: column missing                 */
/***************************************************************************/    
CREATE PROC [dbo].[isp_loadplan_sheet](@c_loadkey NVARCHAR(10))    
AS     
BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @c_delivery_zone      NVARCHAR(10)
           ,@c_load_userdef1      NVARCHAR(200)
           ,@n_ordercnt           INT
           ,@d_adddate            DATETIME
           ,@c_trucksize          NVARCHAR(10)
           ,@c_storerkey          NVARCHAR(15)
           ,@c_orderkey           NVARCHAR(15)
           ,@c_type               NVARCHAR(10)
           ,@c_company            NVARCHAR(45)
           ,@c_teamleader         NVARCHAR(255)
           ,@c_driver             NVARCHAR(255)
           ,@c_deliveryman        NVARCHAR(255)
           ,@c_vehicle            NVARCHAR(255)
           ,@c_descr              NVARCHAR(40)
           ,@c_pmtterm            NVARCHAR(10)
           ,@c_load_userdef2      NVARCHAR(200)
           ,@c_externOrderkey     NVARCHAR(30)
           ,@n_drop               INT
           ,@n_cube               FLOAT
           ,@n_weight             FLOAT
           ,@c_Facility           NVARCHAR(5)
           ,@c_externloadkey      NVARCHAR(20) -- SOS 102426: column missing 
    
    CREATE TABLE #result
    (
       loadkey            NVARCHAR(10)
       ,adddate           DATETIME NULL
       ,teamleader        NVARCHAR(255) NULL
       ,deliveryman       NVARCHAR(255) NULL
       ,trucksize         NVARCHAR(10) NULL
       ,vehicle           NVARCHAR(255) NULL
       ,driver            NVARCHAR(255) NULL
       ,deliveryarea      NVARCHAR(10) NULL
       ,remark            NVARCHAR(200) NULL
       ,ordercnt          INT NULL
       ,storerkey         NVARCHAR(15) NULL
       ,company           NVARCHAR(45) NULL
       ,remark2           NVARCHAR(200) NULL
       ,dropcnt           INT NULL
       ,CUBE              FLOAT
       ,WEIGHT            FLOAT
       ,facility          NVARCHAR(5)
       ,externloadkey     NVARCHAR(20) -- SOS 102426: column missing
    )    
    
    DELETE 
    FROM   ids_lp_nested_orderkey 
    
    /*
    declare cur1 cursor    FAST_FORWARD READ_ONLY 
    for    
    select a.loadkey, a.delivery_zone, convert(char(200), a.load_userdef1), a.ordercnt, a.lpuserdefdate01, a.trucksize, b.storerkey, b.orderkey, b.pmtterm, b.type, c.company,convert(char(200), a.load_userdef2 )  
    from loadplan a (nolock), orders b (nolock), storer c (nolock)    
    where a.loadkey = b.loadkey    
    and b.storerkey = c.storerkey    
    and a.loadkey = @c_loadkey    
    */
    
    DECLARE cur1 CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT DISTINCT a.loadkey
              ,a.delivery_zone
              ,CONVERT(NVARCHAR(200) ,a.load_userdef1)
              ,a.ordercnt
              ,a.lpuserdefdate01
              ,a.trucksize
              ,b.storerkey
              ,c.company
              ,CONVERT(NVARCHAR(200) ,a.load_userdef2)
              ,a.cube
              ,a.weight
              ,b.facility
              ,a.externloadkey ---- SOS 102426: column missing
        FROM   loadplan a(NOLOCK) 
        JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.LoadKey = a.LoadKey
        JOIN orders b(NOLOCK) ON b.OrderKey = lpd.OrderKey 
        JOIN storer c(NOLOCK) ON c.StorerKey = b.StorerKey 
        WHERE a.loadkey = @c_loadkey 
    
    OPEN cur1 
    
    FETCH NEXT FROM cur1 INTO @c_loadkey, @c_delivery_zone, @c_load_userdef1, @n_ordercnt, @d_adddate, @c_trucksize, 
    @c_storerkey, @c_company, @c_load_userdef2 , @n_cube, @n_weight, @c_facility, @c_externloadkey -- SOS 102426: column missing 
    
    SELECT @n_drop = COUNT(DISTINCT consigneekey)
    FROM   ORDERS(NOLOCK)
    WHERE  loadkey = @c_loadkey
    
    WHILE (@@fetch_status=0)
    BEGIN
        INSERT INTO #result
        VALUES
          (
            @c_loadkey
           ,@d_adddate
           ,@c_teamleader
           ,@c_deliveryman
           ,@c_trucksize
           ,@c_vehicle
           ,@c_driver
           ,@c_delivery_zone
           ,@c_load_userdef1
           ,@n_ordercnt
           ,@c_storerkey
           ,@c_company
           ,@c_load_userdef2
           ,@n_drop
           ,@n_cube
           ,@n_weight
           ,@c_facility
           ,@c_externloadkey
          ) -- SOS 102426: column missing          
        
        FETCH NEXT FROM cur1 INTO @c_loadkey, @c_delivery_zone, @c_load_userdef1, @n_ordercnt, @d_adddate, @c_trucksize, 
        @c_storerkey, @c_company, @c_load_userdef2 , @n_cube, @n_weight, @c_facility, @c_externloadkey -- SOS 102426: column missing
    END 
    
    CLOSE cur1 
    DEALLOCATE cur1 
    
    /**    
    Cur2 - to get team leader    
    **/    
    DECLARE cur2 CURSOR FAST_FORWARD READ_ONLY 
    FOR
        SELECT e.description
        FROM   ids_lp_driver d(NOLOCK)
              ,codelkup e(NOLOCK)
        WHERE  d.drivercode = e.code
               AND d.loadkey = @c_loadkey
               AND e.listname = 'Driver'
               AND e.short = 'TL'
               AND e.long = 'Team Leader' 
    
    OPEN cur2 
    
    FETCH NEXT FROM cur2 INTO @c_descr    
    
    WHILE (@@fetch_status=0)
    BEGIN
        IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_teamleader))<>''
            SELECT @c_teamleader = @c_teamleader+' / '
        
        SET @c_teamleader = @c_teamleader+dbo.fnc_RTrim(@c_descr) -- + ' / '    
        FETCH NEXT FROM cur2 INTO @c_descr
    END 
    
    CLOSE cur2 
    DEALLOCATE cur2    
    
    
    UPDATE #result
    SET    teamleader = @c_teamleader
    --substring(@c_teamleader,1,len(@c_teamleader)-3)    
    
    /**    
    End of getting team leader    
    **/ 
    
    
    
    /**    
    Cur3 - to get delivery man    
    **/    
    DECLARE cur3 CURSOR FAST_FORWARD READ_ONLY 
    FOR
        SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(e.description))
        FROM   ids_lp_driver d(NOLOCK)
              ,codelkup e(NOLOCK)
        WHERE  d.drivercode = e.code
               AND d.loadkey = @c_loadkey
               AND e.listname = 'Driver'
               AND e.short = 'DM'
               AND e.long = 'Delivery Man' 
    
    OPEN cur3 
    
    FETCH NEXT FROM cur3 INTO @c_descr    
    
    WHILE (@@fetch_status=0)
    BEGIN
        IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_deliveryman))<>''
            SELECT @c_deliveryman = @c_deliveryman+' / '
        
        SET @c_deliveryman = @c_deliveryman+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_descr)) -- + ' / '
        FETCH NEXT FROM cur3 INTO @c_descr
    END 
    
    CLOSE cur3 
    DEALLOCATE cur3    
    
    UPDATE #result
    SET    deliveryman = @c_deliveryman 
    --substring(@c_deliveryman,1,len(@c_deliveryman)-3)    
    
    /**    
    End of getting delivery man    
    **/ 
    
    
    
    /**    
    Cur4 - to get driver    
    **/    
    DECLARE cur4 CURSOR FAST_FORWARD READ_ONLY 
    FOR
        SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(e.description))
        FROM   ids_lp_driver d(NOLOCK)
              ,codelkup e(NOLOCK)
        WHERE  d.drivercode = e.code
               AND d.loadkey = @c_loadkey
               AND e.listname = 'Driver'
               AND e.short = 'DR'
               AND e.long = 'Driver' 
    
    OPEN cur4 
    
    FETCH NEXT FROM cur4 INTO @c_descr    
    
    WHILE (@@fetch_status=0)
    BEGIN
        IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_driver))<>''
            SELECT @c_driver = @c_driver+' / '
        
        SET @c_driver = @c_driver+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_descr)) -- + ' / '
        
        FETCH NEXT FROM cur4 INTO @c_descr
    END 
    
    CLOSE cur4 
    DEALLOCATE cur4    
    
    UPDATE #result
    SET    driver = @c_driver -- substring(@c_driver,1,len(@c_driver)-3)    
    
    /**    
    End of getting driver    
    **/    
    
    DECLARE cur5 CURSOR FAST_FORWARD READ_ONLY 
    FOR
        SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(vehiclenumber))
        FROM   ids_lp_vehicle(NOLOCK)
        WHERE  loadkey = @c_loadkey
        ORDER BY
               linenumber 
    
    OPEN cur5 
    
    FETCH NEXT FROM cur5 INTO @c_descr    
    
    WHILE (@@fetch_status=0)
    BEGIN
        IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehicle))<>''
            SELECT @c_vehicle = @c_vehicle+' / '
        
        SET @c_vehicle = @c_vehicle+dbo.fnc_RTrim(@c_descr) -- + ' / '    
        FETCH NEXT FROM cur5 INTO @c_descr
    END 
    
    CLOSE cur5 
    DEALLOCATE cur5    
    
    UPDATE #result
    SET    vehicle = '*'+@c_vehicle -- substring(@c_vehicle,1,len(@c_vehicle)-3)    
    
    SELECT CONVERT(NVARCHAR(30) ,SUSER_SNAME()) 'user_name'
          ,*
    FROM   #result 
    
    DROP TABLE #result    
    
    SET NOCOUNT OFF
END

GO