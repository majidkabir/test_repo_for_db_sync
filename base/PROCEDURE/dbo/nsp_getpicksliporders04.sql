SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipOrders04                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4.2                                                       */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 18-Aug-2005  June          SOS39420 - ULP v54 upgrade bug fixed      */
/* 22-Jun-2006  UngDH         SOS52808 - All pick list must sort by     */
/*                            LogicalLocation                           */
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */
/************************************************************************/
 
CREATE PROC [dbo].[nsp_GetPickSlipOrders04] (@c_loadkey NVARCHAR(10))
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
      ORDERS.InvoiceNo,
      ORDERS.OrderKey,   
      ORDERS.LoadKey,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,   
      ORDERS.DeliveryDate,              
      ORDERS.BuyerPO,   
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      ORDERS.Stop,   
      ORDERS.Door,           
      ORDERS.C_CONTACT1,
      ORDERS.BilltoKey, 
      PACK.CaseCnt,       
      PACK.PackUOM1,   
      PACK.PackUOM3,
      PACK.Qty,      
      PACK.PackUOM4,  
      PACK.Pallet,    
      billto.company as B_company,
      billto.address1 as B_address1,
      billto.address2 as B_address2,
      billto.address3 as B_address3,
      billto.address4 as B_address4,
      consignee.company as C_company,
      consignee.address1 as C_address1,
      consignee.address2 as C_address2,
      consignee.address3 as C_address3,
      consignee.address4 as C_address4,
      ORDERS.PrintFlag,
      Notes=CONVERT(NVARCHAR(250),ORDERS.Notes),
      Prepared = CONVERT(NVARCHAR(10), Suser_Sname()),
      ORDERS.LoadKey as Rdd, --ORDERS.Rdd,
      sku.susr3,
      CODELKUP.description as principal,
      ORDERS.Facility, -- Add by June 11.Jun.03 (SOS11736)
      FacilityDescr = Facility.Descr, -- Add by June 11.Jun.03 (SOS11736)
      LOC.LogicalLocation 
	INTO	#RESULT
	FROM 	LOC (Nolock) join PICKDETAIL (Nolock)
      ON LOC.Loc = PICKDETAIL.Loc
   JOIN ORDERS (Nolock)
      ON ORDERS.OrderKey = PICKDETAIL.OrderKey
   JOIN STORER (Nolock)
      ON ORDERS.StorerKey = STORER.StorerKey
   LEFT OUTER JOIN STORER billto (nolock)
      ON billto.storerkey = ORDERS.billtokey
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
   LEFT OUTER JOIN CODELKUP (nolock)
      ON codelkup.listname = 'PRINCIPAL' and
         codelkup.code = sku.susr3
   INNER JOIN FACILITY (nolock) 
      ON Facility.Facility = ORDERS.Facility -- Add by June 11.Jun.03 (SOS11736)
	WHERE	ORDERDETAIL.loadkey = @c_loadkey
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
      ORDERS.InvoiceNo,
      ORDERS.OrderKey,
      ORDERS.LoadKey,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,   
      ORDERS.DeliveryDate,              
      ORDERS.BuyerPO,   
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      ORDERS.Stop,   
      ORDERS.Door,           
      ORDERS.C_CONTACT1,
      ORDERS.BilltoKey, 
      PACK.CaseCnt,       
      PACK.PackUOM1,   
      PACK.PackUOM3,
      PACK.Qty,      
      PACK.PackUOM4,  
      PACK.Pallet,    
      billto.company,
      billto.address1,
      billto.address2,
      billto.address3,
      billto.address4,
      consignee.company,
      consignee.address1,
      consignee.address2,
      consignee.address3,
      consignee.address4,
      ORDERS.PrintFlag,
      CONVERT(NVARCHAR(250),ORDERS.Notes),
      -- ORDERS.Rdd,
      sku.susr3,
      CODELKUP.description,
      ORDERS.Facility, -- Add by June 11.Jun.03 (SOS11736)
      Facility.Descr,  -- Add by June 11.Jun.03 (SOS11736)
      LOC.LogicalLocation -- SOS52808. All pick list must sort by LogicalLocation
      -- process PICKSLIPNO
   
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
      
      -- Start : SOS31698, Add by June 31.Jan.2005
      -- Honielot request to update the previous P/S# so that same SO# only has 1 P/S#
      -- This is to prevent scanning of previous P/S#
      -- Modify by SHONG on 30-Aug-2005 
      -- Since @c_Loadkey was swap from WaveKey to ExternOrderKey, This statement need to change as well 
		IF EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK) 
					  WHERE Orderkey = @c_orderkey AND 
					        -- Wavekey = @c_loadkey AND 
					        ExternOrderKey = @c_Loadkey AND 
					        zone = '3'
					  AND   PickHeaderkey <> @c_pickslipno)
		BEGIN
			DELETE FROM PICKHEADER WHERE Orderkey = @c_orderkey AND 
			-- Wavekey = @c_loadkey AND 
			ExternOrderKey = @c_Loadkey AND
			zone = '3'
		END
		-- End : SOS31698
		
			-- SOS39420, Changed By June 17.Aug.2005
      -- INSERT PICKHEADER (pickheaderkey, wavekey, orderkey, zone)
			INSERT PICKHEADER (pickheaderkey, externorderkey, orderkey, zone)
				VALUES (@c_pickslipno, @c_loadkey, @c_orderkey, '3')

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
               rdd = @c_loadkey
   		WHERE orderkey = @c_orderkey
      else
         UPDATE #RESULT
   		SET pickslipno = @c_pickslipno
   		WHERE orderkey = @c_orderkey
   end -- while 1

	-- return result set
	SELECT * FROM #RESULT
	-- drop table
	DROP TABLE #RESULT
END

GO