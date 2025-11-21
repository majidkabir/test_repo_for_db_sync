SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipOrders21                            */
/* Creation Date: 12-Oct-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose:  Create PickSlip by Order for IDSHK WTC (SOS39325)          */
/*           Note: Copy from nsp_GetPickSlipOrders14 and modified       */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder21                  */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders21] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
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

   SELECT @c_orderkey = '',
		@c_pickslipno   = '',
		@c_invoiceno    = '',
		@c_storerkey    = '',
		@c_consigneekey = '',
		@b_success      = 0,
		@n_err          = 0,
		@c_errmsg       = '' 


      SELECT PICKDETAIL.PickSlipNo,
      PICKDETAIL.Lot,   
      PICKDETAIL.Loc, 
      PICKDETAIL.ID, 
      PickedQty=SUM(PICKDETAIL.Qty),      
      SKU.DESCR, 
      SKU.Sku,
      SKU.RetailSku,    
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02, 
      LOTATTRIBUTE.Lottable04,
      ORDERS.OrderKey,   
      ORDERS.LoadKey,
      ORDERS.StorerKey,   
      STORER.Company, 
      ORDERS.ConsigneeKey,
      consignee.company AS C_company,   
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
   INTO	#RESULTSET
   FROM 	LOC (NOLOCK) 
   JOIN  PICKDETAIL (NOLOCK) ON (LOC.Loc = PICKDETAIL.Loc) 
   JOIN  ORDERS (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey) 
   JOIN  STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
   LEFT OUTER JOIN STORER CONSIGNEE (NOLOCK) ON (CONSIGNEE.storerkey = ORDERS.consigneekey) 
   JOIN  SKU (NOLOCK) ON (SKU.StorerKey = PICKDETAIL.Storerkey AND SKU.Sku = PICKDETAIL.Sku) 
   JOIN  LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) 
	JOIN  PACK (NOLOCK) ON (PACK.PackKey = SKU.PackKey) 
   JOIN  ORDERDETAIL (NOLOCK) ON (PICKDETAIL.orderkey = ORDERDETAIL.orderkey AND
                                  PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber)
   JOIN  LOADPLAN (NOLOCK) ON (ORDERDETAIL.Loadkey = LOADPLAN.LoadKey) 
   JOIN  CODELKUP NONBATCH (NOLOCK) ON (ORDERS.Type = NONBATCH.Code AND NONBATCH.Listname = 'WTCORDTYPE' AND 
                               NONBATCH.Short <> 'BATCH')
   LEFT OUTER JOIN CODELKUP (NOLOCK) ON (CODELKUP.listname = 'PRINCIPAL' AND CODELKUP.code = SKU.susr3)
	WHERE	ORDERDETAIL.LOADKEY = @c_loadkey
	GROUP BY 
      PICKDETAIL.PickSlipNo,
      PICKDETAIL.Lot,  
      PICKDETAIL.ID, 
      PICKDETAIL.Loc,    
      SKU.DESCR,   
      SKU.Sku,  
      SKU.RetailSku, 
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02, 
      LOTATTRIBUTE.Lottable04,
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
      LOADPLAN.Delivery_Zone 
   ORDER BY LOC.PutawayZone, ORDERS.OrderKey, ORDERS.LoadKey


   DECLARE CurOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

   SELECT DISTINCT orderkey FROM #RESULTSET (NOLOCK) 
    WHERE (ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(pickslipno)),'') = '')
    ORDER BY orderkey 

   OPEN CurOrder 
   FETCH NEXT FROM CurOrder INTO @c_orderkey  

   WHILE @@FETCH_STATUS <> -1  -- CurOrder Loop 
   BEGIN
      IF @@FETCH_STATUS = 0
      BEGIN
         IF ISNULL(@c_orderkey, '0') = '0'
            BREAK
      
         SELECT @c_storerkey = storerkey
           FROM #RESULTSET
          WHERE orderkey = @c_orderkey

         EXECUTE dbo.nspg_GetKey
            'PICKSLIP',
            9,   
 	 		   @c_pickslipno   OUTPUT,
            @b_success   	 OUTPUT,
            @n_err       	 OUTPUT,
            @c_errmsg    	 OUTPUT

         SELECT @c_pickslipno = 'P' + @c_pickslipno            

         INSERT PICKHEADER (pickheaderkey, wavekey, externorderkey, orderkey, zone)
         VALUES (@c_pickslipno, @c_loadkey, @c_loadkey, @c_orderkey, '3')

         -- update PICKDETAIL
		   UPDATE PICKDETAIL
		      SET trafficcop = NULL,
		          pickslipno = @c_pickslipno
          WHERE orderkey = @c_orderkey

         -- update print flag
         UPDATE ORDERS
            SET trafficcop = NULL,
                printflag = 'Y'
          WHERE orderkey = @c_orderkey

         IF EXISTS (SELECT 1 
                      FROM storerconfig (nolock)
                     WHERE storerkey = @c_storerkey
                       AND configkey IN ('WTS-ITF','LORITF')
                       AND svalue = '1')
         BEGIN
            -- update result table
            UPDATE #RESULTSET
               SET pickslipno = @c_pickslipno,
                   loadkey = @c_loadkey
             WHERE orderkey = @c_orderkey
         END
         ELSE
         BEGIN
            UPDATE #RESULTSET
               SET pickslipno = @c_pickslipno
             WHERE orderkey = @c_orderkey
         END
      END -- IF @@FETCH_STATUS = 0 - 1st CurOrder

      FETCH NEXT FROM CurOrder INTO @c_orderkey  
   END -- WHILE @@FETCH_STATUS <> -1 -- CurOrder Loop 

   CLOSE CurOrder 
   DEALLOCATE CurOrder

	-- return result set
	SELECT * FROM #RESULTSET
   
	-- drop table
	DROP TABLE #RESULTSET
END

GO