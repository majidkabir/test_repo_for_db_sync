SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nsp_LoadSheet                                      */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 04-MAR-2014  YTWan         SOS#303595 - PH - Update Loading Sheet RCM*/
/*                            (Wan01)                                   */
/* 14-Sep-2015  CSCHONG       SOS#352276 (CS01)                         */
/************************************************************************/

CREATE PROC [dbo].[nsp_LoadSheet] (
@c_loadkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   --(Wan01) - START
   DECLARE @c_IDS_Company  NVARCHAR(45)

   SET  @c_IDS_Company = ''

   SELECT @c_IDS_Company = ISNULL(RTRIM(Company),'')
   FROM STORER WITH (NOLOCK)
   WHERE Storerkey = 'IDS'

   IF @c_IDS_Company = ''
   BEGIN
      SET @c_IDS_Company = 'LF (Philippines), Inc.' 
   END
   --(Wan01) - END

	SELECT DISTINCT LOADPLAN.loadkey as rdd,		-- load sheet no.
		ISNULL(ORDERS.C_company, '') As Company,	-- customer name -- SOS10507
		ORDERS.consigneekey,	-- shipto code
		ISNULL(ORDERS.C_address1,	'') As Address1, -- shipto address -- SOS10507
		ISNULL(ORDERS.C_address2, '') As Address2, -- SOS10507
		-- invoiceno, -- SOS10507
		orderdate = CONVERT(DATETIME, CONVERT(CHAR, ORDERS.orderdate, 106)), -- SOS13227
		load_adddate = CONVERT(DATETIME, CONVERT(CHAR, loadplan.adddate, 106)), -- SOS13227
		-- invoiceamount, -- SOS11663
		-- warehouse = RIGHT(dbo.fnc_RTrim(receiptloc), 1), -- SOS10507 -- FBR11659 
		-- warehouse = LoadPlan.facility, -- SOS10507 Remark this to revert to original
		-- Add by June 9.Jun.03 (FBR11659)
-- 		warehouse = CASE Facility.userdefine20 WHEN 'BUSR1' THEN LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(SKU.BUSR1)), 10)
-- 															WHEN 'BUSR2' THEN LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(SKU.BUSR2)), 10)
-- 															ELSE '' END,
      warehouse = sku.susr3,
		orders_adddate = CONVERT(DATETIME, CONVERT(CHAR, orders.adddate, 106)), -- SOS13227
		facility.descr,
		orders.Externorderkey, -- SOS10506
		orders.Orderkey, -- SOS13227 Use Orderkey for orders without Externorderkey
      convert(int, RTrim(CODELKUP.Long)) as Long
   , @c_IDS_Company,                       --(Wan01)
   Loadplan.Route AS LRoute,                       --(CS01)
   Loadplan.Externloadkey AS LEXTLoadKey,                --(CS01) 
   Loadplan.Priority AS LPriority,                      --(CS01)
   Loadplan.LPuserdefDate01 AS LPuserdefDate01    --(CS01)  
   FROM LOADPLAN (NOLOCK) JOIN ORDERDETAIL (NOLOCK)
      ON LOADPLAN.loadkey = ORDERDETAIL.loadkey
   JOIN loadplandetail WITH (nolock)on loadplandetail.loadkey = loadplan.loadkey
   JOIN ORDERS (NOLOCK)
      ON ORDERS.orderkey = ORDERDETAIL.orderkey
   JOIN SKU (NOLOCK)
      ON ORDERDETAIL.storerkey = SKU.storerkey
         AND ORDERDETAIL.sku = SKU.sku
   JOIN FACILITY (NOLOCK)
      ON LOADPLAN.facility = FACILITY.facility
   JOIN CODELKUP (NOLOCK)
      ON CODELKUP.Code = SKU.susr3
         AND CODELKUP.listname = 'PRINCIPAL' 
	WHERE ORDERS.loadkey = @c_loadkey
END


GO