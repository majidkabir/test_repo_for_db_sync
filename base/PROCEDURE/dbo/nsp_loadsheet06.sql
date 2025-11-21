SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_LoadSheet06                                    */
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
/* 18-Sep-2015 CSCHONG        SOS#352276 (CS01)                         */
/************************************************************************/

CREATE PROC [dbo].[nsp_LoadSheet06] (
@c_loadkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
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

	SELECT DISTINCT LOADPLAN.loadkey as loadkey,		
		ISNULL(ORDERS.C_company, '') As Company,	
		consigneekey,	-- shipto code
		ISNULL(ORDERS.C_address1,	'') As Address1, -- shipto address 
		ISNULL(ORDERS.C_address2, '') As Address2, 
		orderdate = CONVERT(DATETIME, CONVERT(CHAR, orderdate, 106)), 
		load_adddate = CONVERT(DATETIME, CONVERT(CHAR, loadplan.adddate, 106)), 
      warehouse = sku.susr3,
		orders_adddate = CONVERT(DATETIME, CONVERT(CHAR, orders.adddate, 106)), 
		facility.descr,
		orders.Externorderkey, 
		orders.Orderkey
   , @c_IDS_Company,                       --(Wan01)
   Loadplan.Route AS LRoute,                                                --(CS01)
   Loadplan.Externloadkey AS LEXTLoadKey,                                   --(CS01) 
   Loadplan.Priority AS LPriority,                                          --(CS01)
   Loadplan.LPuserdefDate01 AS LPuserdefDate01    --(CS01)  
   FROM LOADPLAN WITH (NOLOCK) JOIN ORDERDETAIL (NOLOCK)
      ON LOADPLAN.loadkey = ORDERDETAIL.loadkey
   JOIN ORDERS   WITH (NOLOCK)
      ON ORDERS.orderkey = ORDERDETAIL.orderkey
   JOIN SKU      WITH (NOLOCK)
      ON ORDERDETAIL.storerkey = SKU.storerkey
         AND ORDERDETAIL.sku = SKU.sku
   JOIN FACILITY (NOLOCK)
      ON LOADPLAN.facility = FACILITY.facility
	WHERE ORDERS.loadkey = @c_loadkey
END


GO