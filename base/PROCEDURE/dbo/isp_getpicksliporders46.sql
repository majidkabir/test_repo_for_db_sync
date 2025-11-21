SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetPickSlipOrders46                            */
/* Creation Date: 17-Jul-2012                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  250385-ECCO SG Pick Slip                                   */
/*           (modified from nsp_GetPickSlipOrders14)                    */
/*                                                                      */
/* Called By: r_dw_print_pickorder46                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders46] (@c_loadkey NVARCHAR(10))
AS
BEGIN
	 SET NOCOUNT ON 
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @c_orderkey NVARCHAR(10),
		      @c_pickslipno NVARCHAR(10),
		      @c_invoiceno NVARCHAR(10),
		      @c_storerkey NVARCHAR(18),
		      @c_consigneekey NVARCHAR(15),
		      @b_success int,
		      @n_err int,
		      @c_errmsg NVARCHAR(255)
		      
      SELECT PICKDETAIL.PickSlipNo,
      --PICKDETAIL.Lot,   
      PICKDETAIL.Loc, 
      PICKDETAIL.ID, 
      PickedQty=SUM(PICKDETAIL.Qty),      
      SKU.DESCR, 
      SKU.Sku,
      SKU.RetailSku,    
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      --LOTATTRIBUTE.Lottable02, 
      --LOTATTRIBUTE.Lottable04,
      ORDERS.OrderKey,   
      ORDERS.LoadKey,
      ORDERS.StorerKey,   
      STORER.Company, 
      ORDERS.ConsigneeKey,
      consignee.company as C_company,   
      LOADPLAN.lpuserdefdate01,              
      ORDERS.ExternOrderKey,               
      ORDERS.Route, 
      ORDERS.PrintFlag,
      Notes=CONVERT(NVARCHAR(250),ORDERS.Notes),
      PACK.CaseCnt,  
      PACK.InnerPack,
      Loc.Putawayzone,
      Prepared = CONVERT(NVARCHAR(10), Suser_Sname()),
      LOADPLAN.Delivery_Zone 
   INTO	#RESULT
   FROM 	LOC (Nolock) join PICKDETAIL (Nolock)
      ON LOC.Loc = PICKDETAIL.Loc
   JOIN ORDERS (Nolock)
      ON ORDERS.OrderKey = PICKDETAIL.OrderKey
   JOIN STORER (Nolock)
      ON ORDERS.StorerKey = STORER.StorerKey
   LEFT OUTER JOIN STORER consignee (nolock)
      ON consignee.storerkey = ORDERS.consigneekey
   JOIN SKU (Nolock)
      ON SKU.StorerKey = PICKDETAIL.Storerkey and
         SKU.Sku = PICKDETAIL.Sku
   JOIN LOTATTRIBUTE (Nolock)
      ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
	JOIN PACK (Nolock) 
      ON PACK.PackKey = SKU.PackKey
   JOIN ORDERDETAIL (NOLOCK)
      ON PICKDETAIL.orderkey = ORDERDETAIL.orderkey and
         PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber
   JOIN LOADPLAN (NOLOCK) ON ORDERDETAIL.Loadkey = LOADPLAN.LoadKey 
   LEFT OUTER JOIN CODELKUP (nolock)
      ON codelkup.listname = 'PRINCIPAL' and
         codelkup.code = sku.susr3
	WHERE	ORDERDETAIL.LOADKEY = @c_loadkey
	GROUP BY 
      PICKDETAIL.PickSlipNo,
      --PICKDETAIL.Lot,  
      PICKDETAIL.ID, 
      PICKDETAIL.Loc,    
      SKU.DESCR,   
      SKU.Sku,  
      SKU.RetailSku, 
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      --LOTATTRIBUTE.Lottable02, 
      --LOTATTRIBUTE.Lottable04,
      ORDERS.OrderKey,
      ORDERS.LoadKey,
      ORDERS.StorerKey,
      STORER.Company,      
      ORDERS.ConsigneeKey, 
      consignee.company,	  
      LOADPLAN.lpuserdefdate01,
      ORDERS.ExternOrderKey,               
      ORDERS.Route,  
      ORDERS.PrintFlag,
      CONVERT(NVARCHAR(250),ORDERS.Notes), 
      PACK.CaseCnt,
      PACK.InnerPack,
      LOC.PutawayZone,
      LOADPLAN.Delivery_Zone -- SOS# 24821- Change Request
   ORDER BY LOC.PutawayZone, ORDERS.OrderKey, ORDERS.LoadKey

   select @c_orderkey = ''
   while (1=1)
   begin -- while 1
      select @c_orderkey = min(orderkey)
      from #result
      where orderkey > @c_orderkey
         and (pickslipno is null or pickslipno = '')

      if isnull(@c_orderkey, '0') = '0'
         break
      
      select @c_storerkey = storerkey
      from #result
      where orderkey = @c_orderkey

      EXECUTE nspg_GetKey
         'PICKSLIP',
         9,   
 	 		@c_pickslipno     OUTPUT,
   		@b_success   	 OUTPUT,
   		@n_err       	 OUTPUT,
   		@c_errmsg    	 OUTPUT

      SELECT @c_pickslipno = 'P' + @c_pickslipno            

      INSERT PICKHEADER (pickheaderkey, wavekey, externorderkey, orderkey, zone)
				VALUES (@c_pickslipno, @c_loadkey, @c_loadkey, @c_orderkey, '3')

      -- update PICKDETAIL
		UPDATE PICKDETAIL
		SET trafficcop = null,
		    pickslipno = @c_pickslipno
		WHERE orderkey = @c_orderkey

		-- update print flag
		UPDATE ORDERS
		SET trafficcop = null,
		    printflag = 'Y'
		WHERE orderkey = @c_orderkey

      if exists (select 1 
                 from storerconfig (nolock)
                 where storerkey = @c_storerkey
       and configkey in ('WTS-ITF','LORITF')
                    and svalue = '1')
   		-- update result table
   		UPDATE #RESULT
   		SET pickslipno = @c_pickslipno,
                loadkey = @c_loadkey
   		WHERE orderkey = @c_orderkey
      else
         UPDATE #RESULT
   		SET pickslipno = @c_pickslipno
   		WHERE orderkey = @c_orderkey
   
    end -- while 1

	-- return result set
	SELECT *
   FROM #RESULT
   
	-- drop table
	DROP TABLE #RESULT
END

GO