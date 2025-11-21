SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspUpdateGTHConsignee]
 AS
 BEGIN -- main
    SET CONCAT_NULL_YIELDS_NULL OFF
 	update orders
 	set c_company = company,
 		c_address1 = address1,
 		c_address2 = address2,
 		route = isnull(left(dbo.fnc_LTRIM(dbo.fnc_RTRIM(address4)), 2),''),
 		trafficcop = null
 	from orders (nolock) join storer (nolock)
 		on orders.consigneekey = storer.storerkey
 	where orders.storerkey = 'GTH'
   		and orders.sostatus = '0'
 -- commented out by WALLY : 02may02
 -- performance tuning
 -- the script below is equivalent to the one above, with much more efficiency

 END -- main

GO