SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : isp_generate_delivery_receipt                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: For Watson PH                                               */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When Udpate Order Header Record                           */
/*                                                                      */
/* PVCS Version: 1.11                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 06-Apr-2005	 June          SOS32084 - Update SOstatus to '8' when    */
/*                            new DR is printed & generate TRXLOG2      */
/*                            'WTS-DR' record.                          */
/* 24-Jun-2005  Shong         Reduce locking                            */
/* 07-Jul-2005  MaryVong      SOS37489 Change print seq. to Orders.Zip  */
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[isp_generate_delivery_receipt]
   @c_LoadKey NVARCHAR(10),
   @c_shipmanifest NVARCHAR(20)
AS
BEGIN -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_ChildLoad NVARCHAR(10),
            @b_success int,
            @c_drnum NVARCHAR(15),
            @n_err int,
            @c_errmsg NVARCHAR(255),
            @c_transmitlog2key NVARCHAR(10),
            @c_reprint NVARCHAR(1),
            @c_userdefine NVARCHAR(20),
            @c_externorderkey NVARCHAR(30)

-- TraceInfo
declare    @c_starttime            datetime,
           @c_endtime              datetime,
           @c_step1                datetime,
           @c_step2                datetime,
           @c_step3                datetime,
           @c_step4                datetime,
           @c_step5                datetime
-- TraceInfo           

   if @c_shipmanifest <> '0' and dbo.fnc_RTrim(dbo.fnc_LTrim(@c_shipmanifest)) <> '' -- reprint only
   begin

      -- Step 1
      set @c_starttime = getdate()

      -- return result set
      select 'Y',
         o.consigneekey,
         o.c_company,
         o.c_address1,
         o.c_address2,
         o.c_address3,
         lp.userdefine10,
         lp.LoadKey,
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
			st.zip
         -- st.state -- SOS37489
      from orders o (nolock) join orderdetail od (nolock)
         on o.orderkey = od.orderkey
      join loadplan lp (nolock)
         on od.LoadKey = lp.LoadKey
      join sku s (nolock)
         on od.storerkey = s.storerkey
            and od.sku = s.sku 
      left outer join po (nolock)
         on o.pokey = po.xdockpokey
      left outer join storer st (nolock)
         on o.consigneekey = st.storerkey
      where lp.LoadKey = @c_LoadKey
         and lp.userdefine10 = @c_shipmanifest
         and o.storerkey = 'WATSONS'
      group by o.printflag,
         o.consigneekey,
         o.c_company,
         o.c_address1,
         o.c_address2,
         o.c_address3,
         lp.userdefine10,
         lp.LoadKey,
         po.sellername,
         od.sku,
         s.busr7,
         s.descr,
         s.price,
			st.zip
         -- st.state -- SOS37489
      having sum(od.qtyallocated+od.qtypicked+od.shippedqty) > 0

   -- Step 1
   set @c_step1 = getdate()- @c_starttime

   end
   else -- new generation
   begin -- else
      if exists (select 1 
	               from loadplan (nolock)
	               where userdefine09 = @c_LoadKey 
	                and dbo.fnc_RTrim(userdefine10) is null )
      begin
         select @c_ChildLoad = ''

         -- Step 1
         set @c_starttime = getdate()

         DECLARE CUR1 CURSOR READ_ONLY FAST_FORWARD FOR 
         select LoadKey
         from loadplan (nolock)
         where userdefine09 = @c_LoadKey
           and dbo.fnc_RTrim(userdefine10) is null
         ORDER BY LoadKey 

         OPEN CUR1

         FETCH NEXT FROM CUR1 INTO @c_ChildLoad


         WHILE @@Fetch_Status <> -1
         BEGIN
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
               select @c_drnum = 'I' + @c_drnum

               begin tran

               update loadplan with (rowlock) 
               set trafficcop = null,
                   userdefine10 = @c_drnum 
               where LoadKey = @c_ChildLoad 

               select @n_err = @@error
               if @n_err = 0
                  commit tran
               else
               begin
                  rollback tran
                  select @c_errmsg = 'Update on Loadplan for Shipping Manifest# Failed.'
                  execute nsp_logerror 
                     @@error,                        -- error id
                     @c_errmsg,  -- error msg
                     'isp_generate_delivery_receipt' -- module      
                  RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
                  return
               end	
            end -- 3

            FETCH NEXT FROM CUR1 INTO @c_ChildLoad
         END -- while 1 
         CLOSE CUR1 
         DEALLOCATE CUR1 

         -- Step 1
         set @c_step1 = getdate()- @c_starttime


         -- Step 2
         set @c_step2 = getdate()

	      -- Start : SOS32084 - Add by June 06.Apr.05 
         -- Update Orders.Status to '8' for New DR		
         DECLARE @cOrderKey NVARCHAR(10) 

         DECLARE CUR2 CURSOR FAST_FORWARD READ_ONLY FOR 
   			SELECT OrderKey 
              FROM ORDERS (NOLOCK) 
				 JOIN  LoadPlan (NOLOCK) ON ORDERS.LoadKey = LoadPlan.LoadKey
				 WHERE ORDERS.SOStatus < '8' AND 
                   LoadPlan.userdefine09 = @c_LoadKey
             ORDER By OrderKey 

          OPEN CUR2

          FETCH NEXT FROM CUR2 INTO @cOrderKey 
   
          WHILE @@fetch_status <> -1
          BEGIN 
            BEGIN TRAN 
            
				UPDATE ORDERS WITH (ROWLOCK) 
				SET   SOStatus = '8',  
						 Editdate = getdate(), 
	             	 Editwho  = Suser_Sname(),
						 TRAFFICCOP = NULL             					 
				WHERE  ORDERS.OrderKey = @cOrderKey 
	
				select @n_err = @@error
	         if @n_err = 0 
	            commit tran
	         else 
	         begin 
	            rollback tran 
	            select @c_errmsg = 'Update Failed on ORDERS.' 
	            execute nsp_logerror 
	               @@error,                        -- error id
	               @c_errmsg,  -- error msg
	               'isp_generate_delivery_receipt' -- module      
	            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	            return
	         end
            FETCH NEXT FROM CUR2 INTO @cOrderKey 
   		END 
         CLOSE CUR2
         DEALLOCATE CUR2 
	      -- End : SOS32084

         -- Step 2
         set @c_step2 = getdate() - @c_step2


         SELECT @b_success = 1

         set @c_step3 = getdate()

         EXEC ispGenTransmitLog2 'WTS-DR', @c_LoadKey, '', '', ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT    
               
		   IF @b_success <> 1
		   BEGIN
	         select @n_err = 72800 -- manually set
	         select @c_errmsg = 'Generate WTS-DR Transmitlog2 Interface failed.'
	         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	         return         
			END 

         set @c_step3 = getdate() - @c_step3
     
         set @c_step4 = getdate()

	      -- return result set
	      select 'N',
	         o.consigneekey,
	         o.c_company,
	         o.c_address1,
	         o.c_address2,
	         o.c_address3,
	         lp.userdefine10,
	         lp.LoadKey,
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
   			st.zip
            -- st.state -- SOS37489
	      from orders o (nolock) 
         join orderdetail od (nolock) on o.orderkey = od.orderkey
	      join loadplan lp (nolock) on od.LoadKey = lp.LoadKey
	      join sku s (nolock) on od.storerkey = s.storerkey and od.sku = s.sku 
	      left outer join po (nolock) on o.pokey = po.xdockpokey
	      left outer join storer st (nolock) on o.consigneekey = st.storerkey
			join storerconfig (nolock) on storerconfig.Storerkey = o.storerkey and 
                                       storerconfig.configkey = 'WTS-ITF' 
                                       and svalue = '1'
	      where lp.userdefine09 = @c_LoadKey
	      group by o.consigneekey,
	         o.c_company,
	         o.c_address1,
	         o.c_address2,
	         o.c_address3,
	         lp.userdefine10,
	         lp.LoadKey,
	         po.sellername,
	         od.sku,
	         s.busr7,
	         s.descr,
	         s.price,
   			st.zip
            -- st.state -- SOS37489
	      having sum(od.qtyallocated+od.qtypicked+od.shippedqty) > 0

           set @c_step4 = getdate() - @c_step4

	   end -- not exists
	   else -- do not allow batch re-print
	   begin
	      select @n_err = 72800 -- manually set
	      select @c_errmsg = 'Batch Re-Print Not Allowed.'
	      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	      return         
	   end
   end -- else

-- BEGIN TRAN
--    set @c_endtime = getdate()                 
--    INSERT INTO TraceInfo VALUES 
--    ('isp_generate_delivery_receipt,'+@c_LoadKey+','+@c_shipmanifest,@c_starttime,@c_endtime, 
--     convert(char(12),@c_endtime-@c_starttime ,114),
--     convert(char(12),@c_step1,114),convert(char(12),@c_step2,114),
--     convert(char(12),@c_step3,114),convert(char(12),@c_step4,114),
--     convert(char(12),@c_step5,114))
-- COMMIT TRAN

END -- main


GO