SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/ 
/* Object Name: isp_ea_gst_invoice                                         */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  FBR - Ticket # 468                                          */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 11-Apr-2002  YokeBeen  1.0   Initial revision                           */
/* 14-Mar-2012  KHLim01   1.1   Update EditDate                            */
/***************************************************************************/   
CREATE PROC [dbo].[isp_ea_gst_invoice](
			@c_storerkey NVARCHAR(15),
			@c_inv_no	 NVARCHAR(10),
			@c_confirm	 NVARCHAR(1),
			@c_reprint	 NVARCHAR(1)
)

AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	declare @c_status		 NVARCHAR(1),
	        @c_wms_inv	 NVARCHAR(10),
	        @c_EAInvoiceKey NVARCHAR(10),
	        @b_success		int,
	        @n_err				int,
	        @c_errmsg		 NVARCHAR(250),
	        @c_ncounter_key NVARCHAR(30),
	        @c_inv_found	 NVARCHAR(10),
			  @n_amount			decimal(10,4)
    
if @c_reprint = 'Y'
   select @c_wms_inv = userdefine01, @c_status = status, @c_inv_found = invoiceno from orders(nolock)
   where userdefine01 = @c_inv_no
else
   select @c_wms_inv = userdefine01, @c_status = status, @c_inv_found = invoiceno from orders(nolock)
   where invoiceno = @c_inv_no
    

if (dbo.fnc_RTrim(@c_wms_inv) is null or @c_wms_inv='') and (dbo.fnc_RTrim(@c_inv_found) is not null)
begin
   if @c_confirm = 'Y'
   begin
      set @c_ncounter_key = dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) + 'InvoiceKey'
      EXECUTE nspg_getkey @c_ncounter_key , 10, @c_EAInvoiceKey OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
      if @b_success = 1  
         update orders
         set userdefine01 = @c_EAInvoiceKey, printflag = 'Y', userdefine02 = '1', trafficcop=null
             ,EditDate = GETDATE() -- KHLim01
         where invoiceno = @c_inv_no
   end

   if @c_status = '5'
   begin
		select @n_amount = sum(ORDERDETAIL.QtyPicked * ORDERDETAIL.UnitPrice)
        from ORDERDETAIL (nolock)
		 inner join ORDERS (nolock) ON ORDERS.OrderKey = ORDERDETAIL.Orderkey
       where ORDERS.invoiceno = @c_inv_no
      	and ORDERS.storerkey = @c_storerkey 

      UPDATE ORDERS
	      set UserDefine03 = convert(NVARCHAR(20), (ROUND(convert(decimal(10,4), @n_amount), 2))),
             EditDate = GETDATE(), -- KHLim01
             trafficCop = NULL
      where invoiceno = @c_inv_no
        and ORDERS.storerkey = @c_storerkey

      select ORDERS.userdefine01, 
             ORDERS.userdefine06,
             ORDERS.b_company,
             ORDERS.b_address1,
             ORDERS.b_address2,
             ORDERS.b_address3,
             ORDERS.b_address4,
             ORDERS.b_country,
             ORDERS.b_zip,
             ORDERS.externorderkey,
             ORDERS.buyerpo,
             ORDERS.pmtterm,
             ORDERS.b_vat,
             ORDERS.invoiceno,
             STORER.b_company,
             STORER.company,
             STORER.address1,
             STORER.address2,
             STORER.address3,
             STORER.zip,
             STORER.contact2,
             STORER.creditlimit,
				 case isnumeric(ORDERS.userdefine03)
					when 1 then cast(ORDERS.userdefine03 as decimal(10,2))
             	else 0.00
				 end,
             STORER.Phone1,
             STORER.Fax1 
      from ORDERS (nolock)
		inner join STORER (nolock) ON ORDERS.StorerKey = STORER.storerkey
      where ORDERS.invoiceno = @c_inv_no
        and ORDERS.storerkey = @c_storerkey
   end  
   else if @c_status = '9'
   begin
		select @n_amount = sum(ORDERDETAIL.ShippedQty * ORDERDETAIL.UnitPrice)
        from ORDERDETAIL (nolock)
		 inner join ORDERS (nolock) ON ORDERS.OrderKey = ORDERDETAIL.Orderkey
       where ORDERS.invoiceno = @c_inv_no
      	and ORDERS.storerkey = @c_storerkey ;

      UPDATE ORDERS
	      set UserDefine03 = convert(NVARCHAR(20), (ROUND(convert(decimal(10,4), @n_amount), 2))),
             EditDate = GETDATE(), -- KHLim01
             trafficCop = NULL
      where invoiceno = @c_inv_no
        and ORDERS.storerkey = @c_storerkey

      select ORDERS.userdefine01, 
             ORDERS.userdefine06,
             ORDERS.b_company,
             ORDERS.b_address1,
             ORDERS.b_address2,
             ORDERS.b_address3,
             ORDERS.b_address4,
             ORDERS.b_country,
             ORDERS.b_zip,
             ORDERS.externorderkey,
             ORDERS.buyerpo,
             ORDERS.pmtterm,
             ORDERS.b_vat,
             ORDERS.invoiceno,
             STORER.b_company,
             STORER.company,
             STORER.address1,
             STORER.address2,
             STORER.address3,
             STORER.zip,
             STORER.contact2,
             STORER.creditlimit,
				 case isnumeric(ORDERS.userdefine03)
					when 1 then cast(ORDERS.userdefine03 as decimal(10,2))
             	else 0.00
				 end,
             STORER.Phone1,
             STORER.Fax1 
      from ORDERS (nolock)
		inner join STORER (nolock) ON ORDERS.StorerKey = STORER.storerkey
      where ORDERS.invoiceno = @c_inv_no
        and ORDERS.storerkey = @c_storerkey
   end -- else status = 9
end
else
begin
   if @c_reprint = 'Y' and @c_confirm = 'N'
   begin
      if @c_status = '5'
      begin
         select ORDERS.userdefine01, 
                ORDERS.userdefine06,
                ORDERS.b_company,
                ORDERS.b_address1,
                ORDERS.b_address2,
                ORDERS.b_address3,
                ORDERS.b_address4,
                ORDERS.b_country,
                ORDERS.b_zip,
                ORDERS.externorderkey,
                ORDERS.buyerpo,
                ORDERS.pmtterm,
                ORDERS.b_vat,
                ORDERS.invoiceno,
                STORER.b_company,
                STORER.company,
	             STORER.address1,
	             STORER.address2,
	             STORER.address3,
	             STORER.zip,
	             STORER.contact2,
	             STORER.creditlimit,
					 case isnumeric(ORDERS.userdefine03)
						when 1 then cast(ORDERS.userdefine03 as decimal(10,2))
                	else 0.00
					 end,
	             STORER.Phone1,
	             STORER.Fax1 
	      from ORDERS (nolock)
			inner join STORER (nolock) ON ORDERS.StorerKey = STORER.storerkey
	      where ORDERS.userdefine01 = @c_inv_no
	        and ORDERS.storerkey = @c_storerkey
      end  
      else if @c_status = '9'
      begin
         select ORDERS.userdefine01, 
                ORDERS.userdefine06,
                ORDERS.b_company,
                ORDERS.b_address1,
                ORDERS.b_address2,
                ORDERS.b_address3,
                ORDERS.b_address4,
                ORDERS.b_country,
                ORDERS.b_zip,
                ORDERS.externorderkey,
                ORDERS.buyerpo,
                ORDERS.pmtterm,
                ORDERS.b_vat,
                ORDERS.invoiceno,
                STORER.b_company,
                STORER.company,
	             STORER.address1,
	             STORER.address2,
	             STORER.address3,
	             STORER.zip,
	             STORER.contact2,
	             STORER.creditlimit,
					 case isnumeric(ORDERS.userdefine03)
						when 1 then cast(ORDERS.userdefine03 as decimal(10,2))
                	else 0.00
					 end,
	             STORER.Phone1,
	             STORER.Fax1 
	      from ORDERS (nolock)
			inner join STORER (nolock) ON ORDERS.StorerKey = STORER.storerkey
	      where ORDERS.userdefine01 = @c_inv_no
	        and ORDERS.storerkey = @c_storerkey
      end
         
      update orders
      set UserDefine02 = convert(NVARCHAR(20),(convert(integer, UserDefine02) + 1)),
          EditDate = GETDATE(), -- KHLim01
          TrafficCop = NULL
      where userdefine01 = @c_inv_no
   end
end

end -- procedure


GO