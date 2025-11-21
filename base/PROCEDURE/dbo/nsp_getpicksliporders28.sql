SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipOrders28 	          								*/
/* Creation Date: 12/02/2009                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW (Modify from nsp_GetPickSlipOrders07)               */
/*                                                                      */
/* Purpose: Shell pick list                                             */
/*                                                                      */
/* Called By: r_dw_print_pickorder28                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 18-Sep-2015  CSCHONG       SOS#352276 (CS01)                         */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders28] (@c_loadkey NVARCHAR(10))
  AS
  BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
  	DECLARE @c_pickslipno NVARCHAR(10),
        @c_chkpickslipno NVARCHAR(10),
        @c_orderkey NVARCHAR(10),
        @c_prevorder NVARCHAR(10), 
        @c_invoiceno NVARCHAR(10),
	  	  @c_storerkey NVARCHAR(18),
	  	  @c_consigneekey NVARCHAR(15),
	  	  @b_success int,
	  	  @n_err int,
	  	  @n_continue int,
	     @n_starttcnt int,
	  	  @c_errmsg NVARCHAR(255),
	  	  @c_locationtype NVARCHAR(10),
	  	  @c_flag NVARCHAR(1)
  SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
  IF @n_continue = 1 or @n_continue = 2
  BEGIN
     SELECT dbo.fnc_RTrim(PICKDETAIL.PickSlipNo) as PickSlipNo,
        dbo.fnc_RTrim(PICKDETAIL.Lot) as Lot,   
        dbo.fnc_RTrim(PICKDETAIL.Loc) as Loc, 
        dbo.fnc_RTrim(PICKDETAIL.ID) as ID, 
        PickedQty=SUM(PICKDETAIL.Qty),      
        dbo.fnc_RTrim(SKU.DESCR) as DESCR,   
        dbo.fnc_RTrim(SKU.Sku) as SKU,   
        dbo.fnc_RTrim(LOTATTRIBUTE.Lottable01) as Lottable01,   
        LOTATTRIBUTE.Lottable04,
        dbo.fnc_RTrim(ORDERS.InvoiceNo) as InvoiceNo,
        dbo.fnc_RTrim(ORDERS.OrderKey) as OrderKey,   
        dbo.fnc_RTrim(ORDERDETAIL.LoadKey) as Loadkey,
        dbo.fnc_RTrim(ORDERS.StorerKey) as Storerkey,   
        dbo.fnc_RTrim(ORDERS.ConsigneeKey) as ConsigneeKey,   
        dbo.fnc_RTrim(STORER.Company) as Company,   
        --dbo.fnc_RTrim(ORDERS.ExternOrderKey) as ExternOrderkey,               
        dbo.fnc_RTrim(ORDERS.Route) as Route,   
        PACK.CaseCnt,       
        dbo.fnc_RTrim(PACK.PackUOM1) as PackUOM1,   
        dbo.fnc_RTrim(PACK.PackUOM3) as PackUOM3,
        PACK.Qty,      
        dbo.fnc_RTrim(PACK.PackUOM4) as PackUOM4,  
        PACK.Pallet,  
        dbo.fnc_RTrim(ORDERS.C_contact1) as C_contact1,
        dbo.fnc_RTrim(ORDERS.C_company) as C_company,
        dbo.fnc_RTrim(ORDERS.C_address1) as C_address1,
        dbo.fnc_RTrim(ORDERS.C_address2) as C_address2,
        dbo.fnc_RTrim(ORDERS.C_address3) as C_address3,
        dbo.fnc_RTrim(ORDERS.C_address4) as C_address4,
        flag = '',
        dbo.fnc_RTrim(ORDERS.Rdd) as Rdd,
  			upper(loc.locationtype) 'locationtype',
        dbo.fnc_RTrim(LOC.LogicalLocation) as LogicalLocation, -- SOS52808. All pick list must sort by LogicalLocation 
        dbo.fnc_RTrim(SKU.Skugroup) as Skugroup,
        dbo.fnc_RTrim(LOTATTRIBUTE.Lottable02) as Lottable02,
        liters = ROUND(SUM(PICKDETAIL.Qty * SKU.cube),2),
        dbo.fnc_RTrim(ORDERS.OrderGroup) as OrderGroup,
		  dbo.fnc_RTrim(ORDERDETAIL.orderlinenumber) as orderlinenumber,
		  loadweight = ROUND(SUM(PICKDETAIL.Qty * SKU.stdgrosswgt),2),
        LRoute=ISNULL(RTRIM(LOADPLAN.Route),'') ,                                  --(CS01)
        LEXTLoadKey = Loadplan.Externloadkey,                                     --(CS01) 
        LPriority = Loadplan.Priority,                                            --(CS01)
        LPuserdefDate01 = Loadplan.LPuserdefDate01                                 --(CS01)  
   	INTO #RESULT
	FROM LOC (nolock),   
        PICKDETAIL (nolock),
        ORDERS (nolock),
        ORDERDETAIL (nolock),
        STORER (nolock),
        SKU (nolock),
        LOTATTRIBUTE (nolock),
        PACK (nolock),
        LOADPLAN (NOLOCK)      --(CS01)
     WHERE	( LOC.Loc = PICKDETAIL.Loc ) and  
     ( SKU.StorerKey = PICKDETAIL.Storerkey ) and  
     ( SKU.Sku = PICKDETAIL.Sku ) and
     ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot ) and
     ( ORDERS.orderkey = ORDERDETAIL.orderkey ) and
     ( ORDERS.OrderKey = PICKDETAIL.OrderKey ) and 
     ( ORDERDETAIL.orderlinenumber = PICKDETAIL.orderlinenumber) and                
     ( ORDERS.StorerKey = STORER.StorerKey ) and
     ( PACK.PackKey = SKU.PackKey ) and 
     ( ORDERDETAIL.LoadKey = @c_loadkey )
     GROUP BY 
     PICKDETAIL.PickSlipNo,
     PICKDETAIL.Lot,   
     PICKDETAIL.Loc, 
     PICKDETAIL.ID, 
     SKU.DESCR,   
     SKU.Sku,   
     LOTATTRIBUTE.Lottable01,   
     LOTATTRIBUTE.Lottable04,
     ORDERS.invoiceNo,
     ORDERS.OrderKey,   
     ORDERDETAIL.LoadKey,
     ORDERS.StorerKey,   
     ORDERS.ConsigneeKey,   
     STORER.Company,   
 --   ORDERS.ExternOrderKey,               
     ORDERS.Route,   
     PACK.CaseCnt,       
     PACK.PackUOM1,   
     PACK.PackUOM3,
     PACK.Qty,      
     PACK.PackUOM4,  
     PACK.Pallet,    
     ORDERS.C_contact1,
     ORDERS.C_company,
     ORDERS.C_address1,
     ORDERS.C_address2,
     ORDERS.C_address3,
     ORDERS.C_address4,
     ORDERS.PrintFlag,
     ORDERS.Rdd,
  	  loc.locationtype,
     LOC.LogicalLocation, -- SOS52808. All pick list must sort by LogicalLocation 
     SKU.Skugroup,
     LOTATTRIBUTE.Lottable02,
     ORDERS.OrderGroup,
	  ORDERDETAIL.orderlinenumber
     ,ISNULL(RTRIM(LOADPLAN.Route),'')                      --(CS01)  
     ,Loadplan.Externloadkey                                --(CS01) 
     ,Loadplan.Priority                                     --(CS01)
     ,Loadplan.LPuserdefDate01                              --(CS01) 
		 
 	if @@rowcount = 0 GOTO RESULT
	if exists (select 1 from pickheader (nolock) where externorderkey = @c_loadkey)
		select @c_flag = 'Y' -- reprint pickslip
	else
		select @c_flag = 'N' -- generate new pickslip
  	if @c_flag = 'N' or @c_flag is null
  	begin -- @c_flag = 'N'    
  		-- process PICKSLIPNO
  		EXECUTE nspg_GetKey
  			'PICKSLIP',
  		  9,   
  		  @c_pickslipno    OUTPUT,
  		  @b_success   	 OUTPUT,
  		  @n_err       	 OUTPUT,
  		  @c_errmsg    	 OUTPUT

      IF @b_success <> 1
      BEGIN
        SELECT @n_continue = 3
 		  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73104   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Get Pickslipno Error. (nsp_GetPickSlipOrders28)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
        GOTO RESULT
      END
  	         
  		SELECT @c_pickslipno = 'P' + @c_pickslipno
  	
  		select @c_storerkey	= (select distinct storerkey from #result (nolock))
  	
  		-- create new record in PICKHEADER table
		-- Remark by June 26.Jul.02 
  		-- INSERT PICKHEADER (pickheaderkey, wavekey, orderkey, externorderkey, storerkey, consigneekey, zone)
  		-- VALUES (@c_pickslipno, @c_loadkey, '', '', @c_storerkey, '', '8')
		
		-- ZONE '7' = Consolidated
      IF NOT EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK) WHERE PICKHEADERKEY = @c_pickslipno)
      BEGIN
	  		INSERT PICKHEADER (pickheaderkey, wavekey, orderkey, externorderkey, storerkey, consigneekey, zone)
	  		VALUES (@c_pickslipno, '', '', @c_loadkey, @c_storerkey, '', '7')
	
	  		SELECT @n_err = @@ERROR
	  		IF @n_err <> 0
	  		BEGIN
	  		  SELECT @n_continue = 3
	 		  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73104   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	  		  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table PICKHEADER. (nsp_GetPickSlipOrders28)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	  		END
     END
     ELSE
     BEGIN
         SELECT @n_continue = 3
	 		SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73104   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	  		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PickslipNo Is Duplicated. Please Check NCounter. (nsp_GetPickSlipOrders28)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         GOTO RESULT
     END
 /* 	
  		IF @n_continue = 1 or @n_continue = 2
  		BEGIN
  			-- update print flag
  			UPDATE loadplan
  			SET trafficcop = null,
  				processflag = 'Y'
  			WHERE loadkey = @c_loadkey
  			SELECT @n_err = @@ERROR
  			IF @n_err <> 0
  			BEGIN
  			   SELECT @n_continue = 3
  			   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73104   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
  			   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table loadplan. (nsp_GetPickSlipOrders28)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
  			END
  		END
*/  	
  		IF @n_continue = 1 or @n_continue = 2
  		BEGIN
  			-- update result table
  			UPDATE #RESULT
  			SET   pickslipno = @c_pickslipno
  			WHERE loadkey = @c_loadkey
  	
  			SELECT @n_err = @@ERROR
  			IF @n_err <> 0
  			BEGIN
  			  SELECT @n_continue = 3
  			  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73104   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
  			  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table RESULT Temp Table. (nsp_GetPickSlipOrders28)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
  			END
  		END
  	  
  		IF @n_continue = 1 or @n_continue = 2
  		BEGIN
  			-- update PICKDETAIL
  			update pickdetail
  			set trafficcop = null,
  					pickslipno = @c_pickslipno
  			from pickdetail join #result
  				on pickdetail.orderkey = #result.orderkey
  					and pickdetail.orderlinenumber = #result.orderlinenumber
  	
  			SELECT @n_err = @@ERROR
  			IF @n_err <> 0
  			BEGIN
  			   SELECT @n_continue = 3
  			   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73104   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
  			   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table PICKDETAIL. (nsp_GetPickSlipOrders28)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
  			END
  		END
  	end -- @c_flag = 'N'
  	else
  	begin
  		update #result set flag = 'Y'
  	end
 RESULT: 
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
     execute nsp_logerror @n_err, @c_errmsg, 'Generation of Pick Slip'
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
  END
  ELSE
  BEGIN
     WHILE @@TRANCOUNT > @n_starttcnt
     BEGIN
        COMMIT TRAN
     END
     --SELECT #RESULT.* , dbo.fnc_RTrim(loadplan.carrierkey), dbo.fnc_RTrim(loadplan.trucksize), dbo.fnc_RTrim(loadplan.driver)
  	  --FROM #RESULT 
     --   JOIN loc (nolock) on #result.loc = loc.loc
     --   JOIN LOADPLAN (nolock) ON #result.loadkey = Loadplan.loadkey
     -- Sort by PB
  	  -- order by #result.locationtype, loc.logicallocation, #result.loc
--    SELECT #RESULT.*, ROUND(Loadplandetail.weight,2) as loadweight
-- 	  FROM #RESULT 
--    JOIN LOADPLANDETAIL (nolock) ON #result.loadkey = Loadplandetail.loadkey
--    AND #result.orderkey = Loadplandetail.orderkey
    SELECT #RESULT.*
 	  FROM #RESULT      
  END
  -- drop table
  DROP TABLE #RESULT
 END
 END /* n_continue <> '3' */

GO