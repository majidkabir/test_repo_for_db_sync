SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger:  ntrLoadPlanDetailAdd                                          */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Input Parameters:                                                       */
/*                                                                         */
/* OUTPUT Parameters:  None                                                */
/*                                                                         */
/* Return Status:  None                                                    */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: When records updated                                         */
/*                                                                         */
/* PVCS Version: 1.13                                                      */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author Ver   Purposes                                      */
/* 03-03-2006   Shong        Add SetROWCOUNT 1                             */
/* 18-06-2007   Shong        SOS80748, Status Not Update when populate     */
/*                           allocated orders into Loadplan.               */
/* 17-03-2008   Shong        SOS100780 Not Allow to populate Order# already*/
/*                           exists in another Loadplan Detail             */
/* 27-03-2009   NJOW01 1.1 SOS132422 - Control orders populate to Load Plan*/
/*                           cannot mix RoutingTool and SOStatus in one lp */ 
/* 06-08-2010   GTGOH  1.2 SOS180734 - Update MBOLDetail.LoadKey if Orders */
/*                           exist in MBOLDetail (GOH01)                   */
/* 13-04-2012   SHONG  1.3   Only Ship Loadplan When All Orders Shipped    */
/* 11-11-2014   NJOW02 1.4   324900-Auto update load plan default strategy */
/*                           flag by storerconfig                          */
/* 18-Jul-2016  SHONG  1.5   Update LoadKey to Pick & Pack Tables          */
/*                           SOS#373412 (SHONG01)                          */ 
/* 20-Sep-2016  TLTING 1.6   Change SetROWCOUNT 1 to Top 1                 */
/* 05-May-2017  TLTING 1.7   Skip if Update TrafficCop = 9                 */
/* 16-May-2017  NJOW03 1.8   WMS-1798 Allow config to call custom sp       */
/* 28-Sep-2018  TLTING 1.9   remove row lock                               */
/***************************************************************************/

CREATE TRIGGER [dbo].[ntrLoadPlanDetailAdd]
 ON  [dbo].[LoadPlanDetail]
 FOR INSERT
 AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
 
 DECLARE
     @b_debug                      INT
,    @b_Success	                 INT	  -- Populated by calls to stored procedures - was the proc successful?
,    @n_err	                       INT	  -- Error number returned by stored procedure or this trigger
,    @n_err2	                    INT       -- For Additional Error Detection
,    @c_errmsg	                    NVARCHAR(250) -- Error message returned by stored procedure or this trigger
,    @n_continue	                 INT                 
,    @n_starttcnt	                 INT       -- Holds the current transaction count
,    @n_cnt	                       INT                  
,	  @c_authority	                 NVARCHAR(1)	 -- Added By Ricky for usage of Configkey
, 	  @c_Facility	                 NVARCHAR(5)	 -- Added By Ricky for usage of Configkey	
,	  @c_StorerKey	                 NVARCHAR(15) -- Added By Ricky for usage of Configkey
,    @c_AutoUpdLoadPlanDefStrategy NVARCHAR(10) --NJOW02
,    @c_PickSlipNo                 NVARCHAR(10) 
,    @c_OrderKey                   NVARCHAR(10)
,    @c_LoadKey                    NVARCHAR(10)
,    @n_RecordsInserted            INT
,    @c_NoMixRoutingTool           NVARCHAR(1)
,    @c_NoMixHoldSOStatus_LP       NVARCHAR(1)
,    @c_DummyRoute                 NVARCHAR(1) 

 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT, @b_debug = 0

 DECLARE @c_SuperOrderFlag NVARCHAR(1)
 SELECT @c_SuperOrderFlag = 'Y' 

 DECLARE @c_RoutingTool NVARCHAR(30), @c_SOStatus NVARCHAR(10), @c_OrderKey2 NVARCHAR(10)  --NJOW01
 
 SET @n_RecordsInserted = 0 
 
 /* #INCLUDE <TRMBODA1.SQL> */
 -- Added By SHONG
 -- 30t Apr 2003 
 -- Do Nothing when ArchiveCop = '9'
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
    IF EXISTS (SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
    BEGIN  
       SELECT @n_continue = 4 
    END  
 END 
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
    IF EXISTS (SELECT 1 FROM INSERTED WHERE TrafficCop = '9')
    BEGIN  
       SELECT @n_continue = 4 
    END  
 END    
 -- End 30th Apr 2003
  
IF (SELECT COUNT(1) FROM INSERTED WHERE TrafficCop is not NULL ) > 0
BEGIN
   UPDATE LoadPlanDetail  
   SET TrafficCop = NULL, ArchiveCop = LoadPlanDetail.ArchiveCop
   FROM INSERTED, DELETED
   WHERE LoadPlanDetail.Loadkey = INSERTED.Loadkey
   AND LoadPlanDetail.LoadLineNumber = INSERTED.LoadLineNumber
   AND LoadPlanDetail.TrafficCop is not NULL 
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
       SELECT @n_continue = 3  
       SELECT @n_err=72609  
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Trigger On LoadPlanDetail Failed. (ntrLoadPlanDetailADD)'
   END
   ELSE
   BEGIN
      SELECT @n_continue = 4
   END
END

 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
 	SET @c_LoadKey = ''
 	
 	SELECT @n_RecordsInserted = COUNT(*) FROM INSERTED
 	 
   IF @n_RecordsInserted = 1
    BEGIN
 	    SELECT @c_OrderKey2 = ORDERKEY, 
 	           @c_LoadKey   = LoadKey  
 	    FROM   INSERTED  	 
    END
    ELSE
    BEGIN
 	    SELECT TOP 1
 	           @c_OrderKey2 = ORDERKEY, 
 	           @c_LoadKey   = LoadKey 
 	    FROM   INSERTED

    	 IF (SELECT COUNT(DISTINCT LoadKey) FROM INSERTED) > 1 
    	   SET @c_LoadKey = '' 
 	       	 	 
    END
 
    SELECT 
          @c_StorerKey = ORDERS.StorerKey, 
 	       @c_RoutingTool = ORDERS.RoutingTool,
          @c_SOStatus = ORDERS.SOStatus, 
          @c_Facility = ORDERS.Facility 
    FROM ORDERS WITH (NOLOCK) 
    WHERE OrderKey = @c_OrderKey2     
 END -- @n_continue=1 or @n_continue=2

--SOS132422 - Control orders populate to Load Plan. By NJOW01 27/03/2009 -START
IF @n_continue=1 or @n_continue=2
BEGIN   
	Select @b_success = 0

	Execute nspGetRight '', 
		@c_StorerKey,   -- Storer
		'',   		      -- Sku
		'NoMixRoutingTool_LP', -- ConfigKey
		@b_success    		 OUTPUT, 
		@c_NoMixRoutingTool OUTPUT, 
		@n_err        		 OUTPUT, 
		@c_errmsg     		 OUTPUT

	IF @b_success <> 1
	BEGIN
		SELECT @n_continue = 3 
		SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72610   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ': Retrieve of Right (NoMixRoutingTool_LP) Failed (ntrLoadPlanDetailAdd)' 
		                 + ' ( ' + ' SQLSvr MESSAGE=' + @c_errmsg + ' ) '
	END   
END

IF (@n_continue=1 or @n_continue=2)
BEGIN
	Select @b_success = 0

	Execute nspGetRight '', 
			@c_StorerKey,   -- Storer
			'',   		-- Sku
			'NoMixHoldSOStatus_LP',  -- ConfigKey
			@b_success    		      OUTPUT, 
			@c_NoMixHoldSOStatus_LP	OUTPUT, 
			@n_err        		      OUTPUT, 
			@c_errmsg     		      OUTPUT

	IF @b_success <> 1
	BEGIN
		SELECT @n_continue = 3 
		SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72611   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Retrieve of Right (NoMixHoldSOStatus_LP) Failed (ntrLoadPlanDetailAdd)' 
		      + ' ( ' + ' SQLSvr MESSAGE=' + @c_errmsg + ' ) '
	End   
END

  
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
    IF EXISTS(SELECT 1 FROM  LOADPLAN (NOLOCK) 
 	  	      JOIN  INSERTED ON LOADPLAN.LoadKey = INSERTED.LoadKey
 	  	      WHERE LOADPLAN.FinalizeFlag = 'Y')
 	 BEGIN
       SELECT @n_continue = 3  
       SELECT @n_err=73000  
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Loadplan has been finalized. ADD rejected. (ntrLoadPlanDetailADD)'    	 	 
       GOTO EXIT_TRIGGER   	
 	 END
 	  	    
    IF EXISTS(SELECT 1 FROM  LOADPLAN (NOLOCK) 
 	  	      JOIN  INSERTED ON LOADPLAN.LoadKey = INSERTED.LoadKey
 	  	      WHERE LOADPLAN.Status = '9') 
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=72900
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': LoadPlan.Status = SHIPPED. UPDATE rejected. (ntrLoadPlanDetailAdd)'
       GOTO EXIT_TRIGGER 
    END 	 	    
           	  	 
 	 DECLARE CUR_VALIDATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
 	 SELECT INSERTED.LoadKey, INSERTED.OrderKey, lp.DummyRoute
 	 FROM INSERTED 
 	 JOIN LoadPlan AS lp WITH(NOLOCK) ON lp.LoadKey = INSERTED.LoadKey 
 	 ORDER BY INSERTED.LoadKey, INSERTED.OrderKey 
 	 
    OPEN CUR_VALIDATION
    FETCH NEXT FROM CUR_VALIDATION INTO @c_LoadKey, @c_OrderKey2, @c_DummyRoute 
    WHILE @@FETCH_STATUS = 0 AND ( @n_continue = 1 OR @n_continue = 2 )
    BEGIN     	 
    	 IF EXISTS( SELECT 1 
    	            FROM LOADPLANDETAIL LPD (NOLOCK) 
    	            WHERE LPD.OrderKey = @c_OrderKey2   
                  AND   LPD.Loadkey <> @c_Loadkey )
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Found Same Order in Different Load Plan Detail. (ntrLoadPlanDetailAdd)'
            BREAK  
        END

        IF @c_NoMixRoutingTool='1'
        BEGIN
           SELECT @c_RoutingTool = ISNULL(ORDERS.RoutingTool, 'Y')  
	        FROM ORDERS (NOLOCK) 
	        WHERE ORDERS.ORDERKEY = @c_OrderKey2 
   
           IF EXISTS(SELECT 1 
               FROM LOADPLANDETAIL WITH (NOLOCK)  
               JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.OrderKey = ORDERS.OrderKey 
               WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
               AND LOADPLANDETAIL.OrderKey <> @c_OrderKey2
               AND ISNULL(ORDERS.RoutingTool,'Y') <> @c_RoutingTool)
           BEGIN
              SELECT @n_continue = 3      
              SELECT @n_err=72611
              SELECT @c_errmsg='RoutingTool: Order No '+ @c_OrderKey2 +' has RoutingTool <> exiting Orders in the Load Plan (ntrLoadPlanDetailAdd)'
              BREAK
           END
        END
        
        IF @c_NoMixHoldSOStatus_LP = '1'
        BEGIN
           IF EXISTS(SELECT 1 
               FROM LOADPLANDETAIL WITH (NOLOCK)  
               JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.OrderKey = ORDERS.OrderKey 
               WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
               AND LOADPLANDETAIL.OrderKey <> @c_OrderKey2
               AND ORDERS.SOStatus <> @c_SOStatus
               AND (@c_SOStatus = 'HOLD' OR ORDERS.SOStatus ='HOLD'))     
           BEGIN
              SELECT @n_continue = 3
              SELECT @n_err=72612
              SELECT @c_errmsg='SOStatus: Order No '+ @c_OrderKey2 +' has Extern Order Status <> existing Orders in the Load Plan (ntrLoadPlanDetailAdd)'
              BREAK
           END                  	
        END
    	 
       UPDATE ORDERS  
          SET LoadKey = @c_LoadKey, 
              Route   = CASE @c_DummyRoute WHEN 'Y' THEN 'XX' ELSE Orders.Route END,
              TrafficCop = NULL, 
              EditDate = GETDATE(),
              EditWho = SUSER_SNAME() 
       WHERE OrderKey = @c_OrderKey2 
       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
       IF @n_err <> 0
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERS. (ntrLoadPlanDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + @c_errmsg + ' ) '
           BREAK
       END

      IF EXISTS (SELECT 1 FROM MBOLDETAIL WITH (NOLOCK)  
                 WHERE MBOLDETAIL.OrderKey = @c_OrderKey2
                   AND (LoadKey = '' OR LoadKey IS NULL) )
      BEGIN  
        UPDATE MBOLDETAIL WITH (ROWLOCK) 
        SET LoadKey = @c_LoadKey, 
            TrafficCop = NULL 
        WHERE MBOLDETAIL.OrderKey = @c_OrderKey2 
        
        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
        IF @n_err <> 0
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table MBOLDETAIL. (ntrLoadPlanDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + @c_errmsg + ' ) '
            BREAK 
        END
     END
          
    	 FETCH NEXT FROM CUR_VALIDATION INTO @c_LoadKey, @c_OrderKey2, @c_DummyRoute  
    END 	  
 	 CLOSE CUR_VALIDATION 
 	 DEALLOCATE CUR_VALIDATION 	 
 END

--NJOW03
IF @n_continue=1 or @n_continue=2          
BEGIN   	  
   IF EXISTS (SELECT 1 FROM INSERTED d   ----->Put INSERTED if INSERT action
            JOIN ORDERS o WITH (NOLOCK) ON d.Orderkey = o.Orderkey
            JOIN storerconfig s WITH (NOLOCK) ON  o.storerkey = s.storerkey    
            JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
            WHERE  s.configkey = 'LoadPlanDetailTrigger_SP')   -----> Current table trigger storerconfig
   BEGIN        	  
      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         DROP TABLE #INSERTED
       
      SELECT * 
      INTO #INSERTED
      FROM INSERTED
              
      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         DROP TABLE #DELETED
       
      SELECT * 
      INTO #DELETED
      FROM DELETED
       
      EXECUTE dbo.isp_LoadPlanDetailTrigger_Wrapper ----->wrapper for current table trigger
               'INSERT'  -----> @c_Action can be INSERT, UPDATE, DELETE
            , @b_Success  OUTPUT  
            , @n_Err      OUTPUT   
            , @c_ErrMsg   OUTPUT  
       
      IF @b_success <> 1  
      BEGIN  
         SELECT @n_continue = 3  
               ,@c_errmsg = 'ntrLoadPlanDetailAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
      END  
             
      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         DROP TABLE #INSERTED
       
      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         DROP TABLE #DELETED
   END
END       

-- Check the Configkey for updating of the superorderflag --> Start by Ricky Yee
IF @n_continue = 1 or @n_continue = 2
BEGIN
	 If @n_continue = 1 or @n_continue = 2  
	 Begin
	 	 Select @b_success = 0
	 	
       SET @c_authority = '0'
       
	 	  Execute nspGetRight 	@c_Facility, 
	 	  			  @c_StorerKey, -- Storer
	 	  			  NULL,			 -- Sku
	 	  			  'AutoUpdSupOrdflag',	-- ConfigKey
	 	  			  @b_success    OUTPUT, 
	 	  			  @c_authority  OUTPUT, 
	 	  			  @n_err        OUTPUT, 
	 	  			  @c_errmsg     OUTPUT
	 	  If @b_success <> 1
	 	  Begin
	 	  	 Select @n_continue = 3, @c_errmsg = 'ntrLoadPlanDetailAdd:' + dbo.fnc_rtrim(@c_errmsg)
	 	  End
	 End
	 
	 --NJOW02
	 If @n_continue = 1 or @n_continue = 2  
	 Begin
	 	  Select @b_success = 0
	 	
        SET @c_AutoUpdLoadPlanDefStrategy = '0'
       
	 	  Execute nspGetRight 	@c_Facility, 
	 	  			  @c_StorerKey, 	        -- Storer
	 	  			  NULL,			-- Sku
	 	  			  'AutoUpdLoadPlanDefStrategy',	-- ConfigKey
	 	  			  @b_success    OUTPUT, 
	 	  			  @c_AutoUpdLoadPlanDefStrategy  OUTPUT, 
	 	  			  @n_err        OUTPUT, 
	 	  			  @c_errmsg     OUTPUT
	 	  If @b_success <> 1
	 	  Begin
	 	  	 Select @n_continue = 3, @c_errmsg = 'ntrLoadPlanDetailAdd:' + dbo.fnc_rtrim(@c_errmsg)
	 	  End
	 End	 
	 
	 -- SHONG01
	 If @n_continue = 1 or @n_continue = 2  
	 BEGIN	 

      DECLARE @cKeepPickHDWhenLpdDelete NVARCHAR(10) 	 	
      
	   SET @cKeepPickHDWhenLpdDelete = ''  
      
      SELECT @cKeepPickHDWhenLpdDelete = ISNULL(sValue, '0')   
      FROM  STORERCONFIG WITH (NOLOCK)   
      WHERE StorerKey = @c_StorerKey   
      AND   ConfigKey = 'KeepPickHDWhenLpdDelete'   
      AND   sVAlue = '1' 
	 END	                   
END

-- Check the Configkey for updating of the superorderflag --> End by Ricky Yee
-- SOS 8113 wally 30.sep.02
-- un-commented out: instead of handling it in loadplan trigger, do the updates in here
IF @n_continue = 1 or @n_continue = 2
BEGIN
   DECLARE @n_casecnt 	           INT,
   		  @n_palletcnt 	        INT,
   		  @n_weight	              FLOAT,
   		  @n_cube		           FLOAT,
   		  @n_custcnt	           INT,
   		  @n_ordercnt	           INT,
           -- SOS80748, Status Not Update when populate allocated orders into Loadplan 
           @n_OrdFullyAllocated    INT,
           @n_OrdPartialAllocated  INT,
           @n_OrdPicked            INT,
           @n_OrdShipped           INT,  
           @n_OrdNormal            INT,  
           @c_Status               NVARCHAR(10)
   

   DECLARE C_InsertLoad CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LoadKey, OrderKey, Weight, [Cube]
      FROM  INSERTED 
      ORDER BY LoadKey, OrderKey 
 
  OPEN C_InsertLoad

   FETCH NEXT FROM C_InsertLoad INTO @c_LoadKey, @c_OrderKey, @n_weight, @n_cube  

   WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2) 
   BEGIN
      SELECT @n_palletcnt = CONVERT(Integer, SUM(CASE WHEN PACK.Pallet = 0 THEN 0
                		                                 ELSE (ORDERDETAIL.OpenQty / PACK.Pallet) END)), 
             @n_casecnt = CONVERT(Integer, SUM(CASE WHEN PACK.CaseCnt = 0 THEN 0
   				                                     ELSE (ORDERDETAIL.OpenQty / PACK.CaseCnt) END)) 
      FROM ORDERDETAIL (NOLOCK) 
      JOIN SKU (NOLOCK) ON (ORDERDETAIL.SKU = SKU.SKU AND ORDERDETAIL.StorerKey = SKU.StorerKey) 
      JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 
      WHERE ORDERDETAIL.OrderKey = @c_OrderKey 

      SELECT @n_custcnt = COUNT(DISTINCT CustomerName)
        -- SOS80748, Status Not Update when populate allocated orders into Loadplan 
        ,@n_OrdFullyAllocated    = SUM(CASE When STATUS = '2' THEN 1 ELSE 0 END)
        ,@n_OrdPartialAllocated  = SUM(CASE When STATUS = '1' THEN 1 ELSE 0 END)
        ,@n_OrdPicked            = SUM(CASE When STATUS = '5' THEN 1 ELSE 0 END)
        ,@n_OrdShipped           = SUM(CASE When STATUS = '9' THEN 1 ELSE 0 END) 
        ,@n_OrdNormal            = SUM(CASE When STATUS = '0' THEN 1 ELSE 0 END) 
      FROM  LOADPLANDETAIL (NOLOCK) 
      WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey 
   
      IF @n_OrdShipped > 0 
         AND (@n_OrdFullyAllocated + @n_OrdPartialAllocated + @n_OrdPicked + @n_OrdNormal) = 0 -- Shong 
         SET @c_Status = '9'
      ELSE IF @n_OrdPicked > 0 
         SET @c_Status = '5'
      ELSE IF @n_OrdPartialAllocated > 0 OR (@n_OrdFullyAllocated > 0 AND @n_OrdNormal > 0 )
         SET @c_Status = '1'
      ELSE IF @n_OrdFullyAllocated > 0 AND @n_OrdNormal = 0 
         SET @c_Status = '2'
      ELSE  
         SET @c_Status = '0'

      -- SOS80748, Status Not Update when populate allocated orders into Loadplan 
      IF @n_casecnt IS NULL SELECT @n_casecnt = 0 
      IF @n_weight IS NULL SELECT @n_weight = 0 
      IF @n_cube IS NULL SELECT @n_cube = 0 
      IF @n_ordercnt IS NULL SELECT @n_ordercnt = 0 
      IF @n_palletcnt IS NULL SELECT @n_palletcnt = 0 
      IF @n_custcnt IS NULL SELECT @n_custcnt = 0 

      IF @c_authority = '1' 
      BEGIN  
         IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE ORDERS.OrderKey = @c_OrderKey AND ORDERS.Rds = 'Y') 
            SELECT @c_SuperOrderFlag = 'N' 
      END 

      UPDATE LoadPlan  
      SET LoadPlan.CustCnt   = @n_custcnt, 
          LoadPlan.OrderCnt  = LoadPlan.OrderCnt + 1,
          LoadPlan.Weight    = LoadPlan.Weight + @n_weight,
          LoadPlan.Cube      = LoadPlan.Cube + @n_cube,
          LoadPlan.PalletCnt = LoadPlan.PalletCnt + @n_palletcnt,
          LoadPlan.CaseCnt   = LoadPlan.CaseCnt + @n_casecnt,
          SuperOrderFlag     = CASE WHEN @c_authority = '1' THEN @c_SuperOrderFlag
                               ELSE SuperOrderFlag END, 
          Status             = @c_Status, -- SOS80748
          Trafficcop         = null, 
          LoadPlan.DefaultStrategykey = CASE WHEN @c_AutoUpdLoadPlanDefStrategy = '1' THEN 'Y' ELSE 'N' END --NJOW02
      WHERE LoadPlan.LoadKey = @c_LoadKey
         
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlan. (ntrLoadPlanDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + @c_errmsg + ' ) '
      END
      
      -- SHONG01
      IF @cKeepPickHDWhenLpdDelete='1'
      BEGIN
         IF EXISTS(SELECT 1 FROM PICKHEADER WITH (NOLOCK) 
      	          WHERE OrderKey = @c_OrderKey 
      	          AND   ExternOrderKey = @c_LoadKey)
         BEGIN
            DECLARE CUR_Added_PickSlipNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT p.PickHeaderKey 
            FROM PICKHEADER AS p WITH (NOLOCK)
            WHERE p.ExternOrderKey = '' 
            AND   p.OrderKey = @c_OrderKey
               	
            OPEN CUR_Added_PickSlipNo 
            FETCH NEXT FROM CUR_Added_PickSlipNo INTO @c_PickSlipNo 
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE PICKHEADER 
            	   SET ExternOrderKey = @c_LoadKey, 
            	      TrafficCop = NULL, 
            	      EditDate = GETDATE(), 
            	      EditWho = SUSER_SNAME() 
               WHERE ExternOrderKey = '' 
            	   AND OrderKey = @c_OrderKey  
            	   AND PickHeaderKey = @c_PickSlipNo  
            	   
               IF EXISTS(SELECT 1 FROM PackHeader AS ph WITH (NOLOCK)
            	            WHERE ph.PickSlipNo = @c_PickSlipNo 
            	            AND   ph.LoadKey = '' 
            	            AND   ph.OrderKey = @c_OrderKey)
               BEGIN
            	   UPDATE PackHeader WITH (ROWLOCK) 
            	      SET LoadKey = @c_LoadKey
            	   WHERE PickSlipNo = @c_PickSlipNo
            	   	            	   	
               END -- PackHeader 
               IF EXISTS(SELECT 1 FROM RefKeyLookup AS rkl WITH (NOLOCK)
            	            WHERE rkl.Pickslipno = @c_PickSlipNo 
            	            AND rkl.OrderKey = @c_OrderKey 
            	            AND rkl.Loadkey = '')
               BEGIN
            	   UPDATE RefKeyLookup
            	      SET Loadkey = @c_LoadKey
            	   WHERE Pickslipno = @c_PickSlipNo 
            	   AND OrderKey = @c_OrderKey 
            	   AND Loadkey = ''
               END -- RefKeyLookup     
                   
               FETCH NEXT FROM CUR_Added_PickSlipNo INTO @c_PickSlipNo      	
            END    
            CLOSE CUR_Added_PickSlipNo 
            DEALLOCATE CUR_Added_PickSlipNo           	         	      
         END -- PICKHEADER
      END -- @cKeepPickHDWhenLpdDelete = 1

      FETCH NEXT FROM C_InsertLoad INTO @c_LoadKey, @c_OrderKey, @n_weight, @n_cube  
   END -- WHILE
   CLOSE C_InsertLoad
   DEALLOCATE C_InsertLoad
END

EXIT_TRIGGER:

 /* #INCLUDE <TRMBODA2.SQL> */
 IF @n_continue=3  -- Error Occured - Process And Return
 BEGIN
    IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
    BEGIN
       ROLLBACK TRAN
    END
    ELSE
    BEGIN
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
          COMMIT TRAN
       END
    END
    execute nsp_logerror @n_err, @c_errmsg, 'ntrLoadPlanDetailAdd'
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
    RETURN
 END
 ELSE
 BEGIN
    WHILE @@TRANCOUNT > @n_starttcnt
    BEGIN
       COMMIT TRAN
    END
    RETURN
 END


GO