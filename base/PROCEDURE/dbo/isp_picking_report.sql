SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_picking_report                           		*/
/* Creation Date:                                     						*/
/* Copyright: IDS                                                       */
/* Written by:                                           					*/
/*                                                                      */
/* Purpose:  Watsons XDOCK PickList 											   */
/*                                                                      */
/* Input Parameters:  @c_poref,  - POKey                                */
/*							 @c_sku	   - Sku                                  */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_picking_report_06         			   */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 01-Dec-2003  Wally      	Bug Fixes - Reprint Pickslip 	            */
/*	15-Mar-2005	 MaryVong		Modified printing order: by delivery zone,*/
/*										consigneekey (SOS33268)							*/
/* 20-Jun-2005  June				SOS37114 - Bug fix Performance issue		*/
/*																								*/
/************************************************************************/

CREATE PROC [dbo].[isp_picking_report]
   @c_poref NVARCHAR(10),
   @c_sku NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   declare @b_success int,
            @c_pickslipno NVARCHAR(10),
            @n_err int,
            @c_errmsg NVARCHAR(255),
            @c_pickdetailkey NVARCHAR(10),
				@b_debug int

	select @b_debug = 0

   if @c_sku <> '0' and dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sku)) <> '' -- reprint specific pickslip by sku
   begin
      select 'Y', -- reprint flag
         p.pickslipno,
         po.xdockpokey, 
   		po.sellersreference,
   		po.sellername,
   		p.storerkey,
   		p.sku,
   		sku.descr,
   		p.orderkey,
   		DeliveryZone = STORER.State,  -- SOS33268
   		consigneekey = convert(int, dbo.fnc_RTrim(substring(orders.consigneekey,5,10))),
   		orders.c_company,
   		totalqty = sum(p.qty),
   		pack.casecnt
   	from po (nolock) join orders (nolock)    
   		on po.xdockpokey = orders.pokey
   	join pickdetail p (nolock)    
   		on orders.orderkey = p.orderkey
   	join sku (nolock)    
   		on sku.storerkey = p.storerkey
   			and sku.sku = p.sku
   	join pack (nolock)     
   		on sku.packkey = pack.packkey
      -- SOS33268
		JOIN STORER (NOLOCK)
			ON STORER.Storerkey = ORDERS.ConsigneeKey  		
   	where p.sku = @c_sku
         and orders.pokey = @c_poref
         and p.pickslipno > ''
         and p.status < '5'
   	group by p.pickslipno,
         po.xdockpokey, 
   		po.sellersreference,
   		po.sellername,
   		p.storerkey,
   		p.sku,
   		sku.descr,
   		p.orderkey,
   		STORER.State,  -- SOS33268
   		orders.consigneekey,
   		orders.c_company,
   		pack.casecnt   

			if @b_debug = 1 
			begin
				select 'reprint ...'

		      select 'Y', -- reprint flag
		         p.pickslipno,
		         po.xdockpokey, 
		   		po.sellersreference,
		   		po.sellername,
		   		p.storerkey,
		   		p.sku,
		   		sku.descr,
		   		p.orderkey,
		   		DeliveryZone = STORER.State,  -- SOS33268
		   		consigneekey = convert(int, dbo.fnc_RTrim(substring(orders.consigneekey,5,10))),
		   		orders.c_company,
		   		totalqty = sum(p.qty),
		   		pack.casecnt
		   	from po (nolock) join orders (nolock)    
		   		on po.xdockpokey = orders.pokey
		   	join pickdetail p (nolock)    
		   		on orders.orderkey = p.orderkey
		   	join sku (nolock)    
		   		on sku.storerkey = p.storerkey
		   			and sku.sku = p.sku
		   	join pack (nolock)     
		   		on sku.packkey = pack.packkey
		      -- SOS33268
				JOIN STORER (NOLOCK)
					ON STORER.Storerkey = ORDERS.ConsigneeKey  		
		   	where p.sku = @c_sku
		         and orders.pokey = @c_poref
		         and p.pickslipno > ''
		         and p.status < '5'
		   	group by p.pickslipno,
		         po.xdockpokey, 
		   		po.sellersreference,
		   		po.sellername,
		   		p.storerkey,
		   		p.sku,
		   		sku.descr,
		   		p.orderkey,
		   		STORER.State,  -- SOS33268
		   		orders.consigneekey,
		   		orders.c_company,
		   		pack.casecnt   
			end

   end
   else -- reprint whole batch?!?
   begin
      select @c_sku = ''
      while (1=1) -- loop 1
      begin
         select @c_sku = min(p.sku)
         from pickdetail p (nolock) join orders o (nolock)
            on p.orderkey = o.orderkey
         where o.pokey = @c_poref
            and p.status < '5'
            and p.sku > @c_sku
            and (p.pickslipno is null or p.pickslipno = '')
   
         if isnull(@c_sku, 0) = 0
            break
   
         select @b_success = 0
         EXECUTE nspg_GetKey
            'PICKSLIP',
            9,   
            @c_pickslipno OUTPUT,
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT
         
         if @b_success = 1
         begin
            SELECT @c_pickslipno = 'P' + @c_pickslipno
            if not exists (select 1 
                           from pickheader (nolock) 
                           where externorderkey = @c_poref 
                              and pickheaderkey = @c_pickslipno
                              and zone = 'W')
               INSERT INTO PICKHEADER (PickHeaderKey, PickType, externorderkey, Zone, TrafficCop)
                   VALUES (@c_pickslipno, '0', @c_poref, 'W', '')
            select @n_err = @@error
            if @n_err = 0
            begin
					-- Start : SOS37114
					/*
               select @c_pickdetailkey = ''
               while (1=1)
               begin
                  select @c_pickdetailkey = min(pickdetailkey)
                  from pickdetail p (nolock) join orders o (nolock)
                      on p.orderkey = o.orderkey
                  where o.pokey = @c_poref
                     and p.sku = @c_sku
                     and p.pickdetailkey > @c_pickdetailkey
                     and p.pickslipno is null

                  if isnull(@c_pickdetailkey, 0) = 0
                     break

                  begin tran
                  update pickdetail
                  set trafficcop = null,
                     pickslipno = @c_pickslipno
                  where pickdetailkey = @c_pickdetailkey
                  select @n_err = @@error
                  if @n_err = 0
                     commit tran
                  else
                  begin
                     select @c_errmsg = 'Pickdetail Update of Pickslipno Failed. (isp_picking_report).'
                     rollback tran      
                     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
                  end                 
               end -- While              
					*/

					if @b_debug = 1
					begin
						select 'new p/s - ', @c_pickslipno
					end

               begin tran
               update pickdetail
               set 	 trafficcop = null,
                  	 pickslipno = @c_pickslipno
				   from  pickdetail p (nolock) 
					join  orders o (nolock) on p.orderkey = o.orderkey
					where o.pokey = @c_poref
         	   and   p.sku = @c_sku
      	      and   p.status < '5'
            	and   (p.pickslipno is null or p.pickslipno = '')
	
               select @n_err = @@error
               if @n_err = 0
                  commit tran
               else
               begin
                  select @c_errmsg = 'Pickdetail Update of Pickslipno Failed. (isp_picking_report).'
                  rollback tran      
                  RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               end            
  
					if @b_debug = 1
					begin
						select pickdetail.pickdetailkey, pickdetail.orderkey, pickdetail.sku, pickdetail.pickslipno
						from   pickdetail (nolock) 
						join  orders (nolock) on pickdetail.orderkey = orders.orderkey
						where orders.pokey = @c_poref
      	   	   and   pickdetail.sku = @c_sku
      		      and   pickdetail.status < '5'	
					end   
					-- End : SOS37114
            end
            else
            begin
               select @c_errmsg = 'Pickheader Insert Failed. (isp_picking_report).'
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            end
         end
         else
         begin
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            return
         end
      end -- loop 1
      -- return result
      select 'N',
         p.pickslipno,
         po.xdockpokey, 
   		po.sellersreference,
   		po.sellername,
   		p.storerkey,
   		p.sku,
   		sku.descr,
   		p.orderkey,
   		DeliveryZone = STORER.State,  -- SOS33268
   		consigneekey = convert(int, dbo.fnc_RTrim(substring(orders.consigneekey,5,10))),
   		orders.c_company,
   		totalqty = sum(p.qty),
   		pack.casecnt
   	from po (nolock) join orders (nolock)    
   		on po.xdockpokey = orders.pokey
   	join pickdetail p (nolock)    
   		on orders.orderkey = p.orderkey
   	join sku (nolock)    
   		on sku.storerkey = p.storerkey
   			and sku.sku = p.sku
   	join pack (nolock)     
   		on sku.packkey = pack.packkey
      -- SOS33268
		JOIN STORER (NOLOCK)
			ON STORER.Storerkey = ORDERS.ConsigneeKey
   	where orders.pokey = @c_poref
         and p.pickslipno > ''
         and p.status < '5'
   	group by p.pickslipno,
         po.xdockpokey, 
   		po.sellersreference,
   		po.sellername,
   		p.storerkey,
   		p.sku,
   		sku.descr,
   		p.orderkey,
   		STORER.State,  -- SOS33268
   		orders.consigneekey,
   		orders.c_company,
 		pack.casecnt
   end -- reprint whole batch?!?
END -- main

GO