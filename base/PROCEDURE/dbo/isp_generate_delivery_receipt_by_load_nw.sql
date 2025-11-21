SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_generate_delivery_receipt_by_load_nw                   */
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
CREATE PROC [dbo].[isp_generate_delivery_receipt_by_load_nw]
   @c_loadkey NVARCHAR(10),
   @c_storerkey NVARCHAR(15)
AS
BEGIN -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   -- Modified by MaryVong on 03Dec2004 (SOS29869)
   -- Allow to print Load Manifest before scan out (changes done Reprint session)
   declare @c_childload NVARCHAR(10),
            @b_success int,
            @c_drnum NVARCHAR(15),
            @n_err int,
            @c_errmsg NVARCHAR(255),
            @c_transmitlog2key NVARCHAR(10),
            @c_reprint NVARCHAR(1),
            @c_userdefine NVARCHAR(20),
            @c_externorderkey NVARCHAR(30)

   if (select dbo.fnc_RTrim(userdefine10) from loadplan (nolock) where loadkey = @c_loadkey) is null
   begin -- new generation
      -- generate shipping manifest #
      SELECT @b_success = 0
      EXECUTE nspg_getkey
         'DR'
         , 7
         , @c_drnum OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT      

      if @b_success = 1
      begin -- 3
         -- update loadplan.userdefine10
         select @c_drnum = 'I'+@c_drnum
         begin tran
         update loadplan
         set trafficcop = null,
            userdefine10 = @c_drnum
         where loadkey = @c_loadkey
         select @n_err = @@error
         if @n_err = 0
            commit tran
         else
         begin
            rollback tran
            execute nsp_logerror 
               @@error,                        -- error id
               'Update on Loadplan for Shipping Manifest# Failed.',  -- error msg
               'isp_generate_delivery_receipt_by_load_nw' -- module      
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            return
         end
   
         -- return result set
         select 'N',
            o.consigneekey,
            o.c_company,
            o.c_address1,
            o.c_address2,
            o.c_address3,
            lp.userdefine10,
            lp.loadkey,
            po.sellername,
            od.sku,
            s.busr7,
            s.descr, 
            sum(od.originalqty) as qtyordered,
            sum(od.qtyallocated+od.qtypicked+od.shippedqty) as qtyshipped,
            (select dbo.fnc_RTrim(company) + ' ' + dbo.fnc_RTrim(address1) + ' ' + dbo.fnc_RTrim(address2) + ' ' + dbo.fnc_RTrim(address3)
             from storer (nolocK) 
             where storerkey = 'IDS') as origin,
            s.price, 
				s.class, 
				s.manufacturersku, 
				o.externorderkey, 
				convert(char(10), o.deliverydate , 112)
         from orders o (nolock) join orderdetail od (nolock)
            on o.orderkey = od.orderkey
         join loadplan lp (nolock)
            on od.loadkey = lp.loadkey
         join sku s (nolock)
            on od.storerkey = s.storerkey
               and od.sku = s.sku 
         left outer join po (nolock)
            on od.externpokey = po.externpokey
         where lp.loadkey = @c_loadkey
            and o.storerkey = @c_storerkey 
         group by o.consigneekey,
            o.c_company,
            o.c_address1,
            o.c_address2,
            o.c_address3,
            lp.userdefine10,
            lp.loadkey,
            po.sellername,
            od.sku,
            s.busr7,
            s.descr,
            s.price, 
				s.class, 
				s.manufacturersku, 
				o.externorderkey, 
				o.deliverydate 
         having sum(od.qtyallocated+od.qtypicked+od.shippedqty) > 0
      end -- 3
   end -- new generation
   else
   begin -- reprint
      -- return result set
      select 'Y',
         o.consigneekey,
         o.c_company,
         o.c_address1,
         o.c_address2,
         o.c_address3,
         lp.userdefine10,
         lp.loadkey,
         po.sellername,
         od.sku,
         s.busr7,
         s.descr,
         sum(od.originalqty) as qtyordered,
         -- sum(od.qtypicked+od.shippedqty) as qtyshipped,
			sum(od.qtyallocated+od.qtypicked+od.shippedqty) as qtyshipped,  -- SOS29869
         (select dbo.fnc_RTrim(company) + ' ' + dbo.fnc_RTrim(address1) + ' ' + dbo.fnc_RTrim(address2) + ' ' + dbo.fnc_RTrim(address3)
          from storer (nolocK) 
          where storerkey = 'IDS') as origin,
         s.price, 
			s.class, 
			s.manufacturersku, 
			o.externorderkey, 
			convert(char(10), o.deliverydate , 112)
      from orders o (nolock) join orderdetail od (nolock)
         on o.orderkey = od.orderkey
      join loadplan lp (nolock)
         on od.loadkey = lp.loadkey
      join sku s (nolock)
         on od.storerkey = s.storerkey
            and od.sku = s.sku 
      left outer join po (nolock)
         on od.externpokey = po.externpokey
      where lp.loadkey = @c_loadkey
         and o.storerkey = @c_storerkey
      group by o.consigneekey, 
         lp.loadkey,
			o.printflag,
         o.c_company,
         o.c_address1,
         o.c_address2,
         o.c_address3,
         lp.userdefine10,
         po.sellername,
         od.sku,
         s.busr7,
         s.descr,
         s.price, 
			s.class, 
			s.manufacturersku, 
			o.externorderkey, 
			o.deliverydate 
   end -- reprint
END -- main


GO