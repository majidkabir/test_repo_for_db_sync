SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipOrders16                        		*/
/* Creation Date: 24-Mar-2005                           						*/
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                    					*/
/*                                                                      */
/* Purpose:  Create PickSlip (16) - IDSHK ARH HUB (SOS33138)            */
/*           Modified from nsp_GetPickSlipOrders14: added Lottable03    */
/*           and Lottable05                                             */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - LoadKey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder16         			*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*                                                                      */
/* 29-Apr-2015  CSCHONG       SOS339808  (CS01)                         */
/* 09-Jul-2015  CSCHONG       SOS346307 (CS02)                          */
/************************************************************************/

CREATE  PROC [dbo].[nsp_GetPickSlipOrders16] (@c_loadkey NVARCHAR(10))
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

   
		
      SELECT PICKDETAIL.PickSlipNo,
      PICKDETAIL.Lot,   
      PICKDETAIL.Loc, 
      PICKDETAIL.ID, 
      PickedQty=SUM(PICKDETAIL.Qty),      
      SKU.DESCR, 
      SKU.Sku,
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02, 
      LOTATTRIBUTE.Lottable03,
      LOTATTRIBUTE.Lottable04,   
      LOTATTRIBUTE.Lottable05,
      ORDERS.OrderKey,   
      ORDERS.LoadKey,
      ORDERS.StorerKey,   
      STORER.Company, 
      ORDERS.ConsigneeKey,
      Consignee.company as C_company,   
      LOADPLAN.lpuserdefdate01,              
      ORDERS.ExternOrderKey,               
      ORDERS.Route, 
      ORDERS.PrintFlag,
      Notes=CONVERT(NVARCHAR(250),ORDERS.Notes),
      PACK.CaseCnt,  
      PACK.InnerPack,
      Loc.Putawayzone,
      Prepared = CONVERT(NVARCHAR(10), suser_sname()),
      LOADPLAN.Delivery_Zone,
      Loadplan.Route AS LRoute,                       --(CS01)
      Loadplan.Externloadkey,                --(CS01) 
      Loadplan.Priority,                      --(CS01)
      --Loadplan.UserDefine01 AS LUdef01        --(CS01)   --(CS02)
      REPLACE(CONVERT(NVARCHAR(12),Loadplan.LPuserdefDate01,106),' ','/') AS LUdef01--(CS02)
   INTO	#RESULT
   FROM 	LOC (NOLOCK) JOIN PICKDETAIL (NOLOCK)
      ON LOC.Loc = PICKDETAIL.Loc
   JOIN ORDERS (NOLOCK)
      ON ORDERS.OrderKey = PICKDETAIL.OrderKey
   JOIN STORER (NOLOCK)
      ON ORDERS.StorerKey = STORER.StorerKey
   LEFT OUTER JOIN STORER Consignee (nolock)
      ON Consignee.storerkey = ORDERS.consigneekey
   JOIN SKU (NOLOCK)
      ON SKU.StorerKey = PICKDETAIL.Storerkey AND
         SKU.Sku = PICKDETAIL.Sku
   JOIN LOTATTRIBUTE (NOLOCK)
      ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
	JOIN PACK (NOLOCK) 
      ON PACK.PackKey = SKU.PackKey
   JOIN ORDERDETAIL (NOLOCK)
      ON PICKDETAIL.orderkey = ORDERDETAIL.orderkey AND
         PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber
   JOIN LOADPLAN (NOLOCK) ON ORDERDETAIL.Loadkey = LOADPLAN.LoadKey 
   LEFT OUTER JOIN CODELKUP (NOLOCK)
      ON CODELKUP.ListName = 'PRINCIPAL' AND
         CODELKUP.Code = SKU.SUSR3
	WHERE	ORDERDETAIL.LOADKEY = @c_loadkey
	GROUP BY 
      PICKDETAIL.PickSlipNo,
      PICKDETAIL.Lot,  
      PICKDETAIL.ID, 
      PICKDETAIL.Loc,    
      SKU.DESCR,   
      SKU.Sku,  
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02, 
      LOTATTRIBUTE.Lottable03,
      LOTATTRIBUTE.Lottable04,   
      LOTATTRIBUTE.Lottable05,  
      ORDERS.OrderKey,
      ORDERS.LoadKey,
      ORDERS.StorerKey,
      STORER.Company,      
      ORDERS.ConsigneeKey, 
      Consignee.company,	  
      LOADPLAN.lpuserdefdate01,
      ORDERS.ExternOrderKey,               
      ORDERS.Route,  
      ORDERS.PrintFlag,
      CONVERT(NVARCHAR(250),ORDERS.Notes), 
      PACK.CaseCnt,
      PACK.InnerPack,
      LOC.PutawayZone,
      LOADPLAN.Delivery_Zone,
      Loadplan.Route ,                       --(CS01)
      Loadplan.Externloadkey,                --(CS01) 
      Loadplan.Priority,                     --(CS01) 
      --Loadplan.UserDefine01                  --(CS01) --(CS02)
      REPLACE(CONVERT(NVARCHAR(12),Loadplan.LPuserdefDate01,106),' ','/') --(CS02)
   ORDER BY LOC.PutawayZone, ORDERS.OrderKey, ORDERS.LoadKey

   SELECT @c_orderkey = ''
   WHILE (1=1)
   BEGIN -- WHILE 1
      SELECT @c_orderkey = MIN(orderkey)
      FROM #result
      WHERE orderkey > @c_orderkey
         AND (pickslipno IS NULL OR pickslipno = '')

      IF ISNULL(@c_orderkey, '0') = '0'
         BREAK
      
      SELECT @c_storerkey = storerkey
      FROM #result
      WHERE orderkey = @c_orderkey

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
		SET trafficcop = NULL,
		    pickslipno = @c_pickslipno
		WHERE orderkey = @c_orderkey

		-- update print flag
		UPDATE ORDERS
		SET trafficcop = NULL,
		    printflag = 'Y'
		WHERE orderkey = @c_orderkey

      IF EXISTS (SELECT 1 
                 FROM Storerconfig (NOLOCK)
                 WHERE storerkey = @c_storerkey
       AND configkey IN ('WTS-ITF','LORITF')
                    AND svalue = '1')
   		-- update result table
   		UPDATE #RESULT
   		SET pickslipno = @c_pickslipno,
                loadkey = @c_loadkey
   		WHERE orderkey = @c_orderkey
      ELSE
         UPDATE #RESULT
   		SET pickslipno = @c_pickslipno
   		WHERE orderkey = @c_orderkey   
    END -- WHILE 1

	-- return result set
	SELECT *
   FROM #RESULT
   
	-- drop table
	DROP TABLE #RESULT
END

GO