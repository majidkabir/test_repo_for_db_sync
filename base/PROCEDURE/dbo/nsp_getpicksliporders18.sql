SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipOrders18                        		*/
/* Creation Date: 4-JUL-2005                           						*/
/* Copyright: IDS                                                       */
/* Written by: Ong                                               			*/
/*                                                                      */
/* Purpose:  Create Sort List Pickslip for IDSHK WTC (SOS37179)         */
/*           Note: Copy from nsp_GetPickSlipOrders14 and modified       */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder18                  */
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
/* 24Aug2005   Ong         Change sorting from loadkey, sku, orderkey   */
/*                         to loadkey,sku, consigneekey,orderkey        */
/*																								*/
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders18] (@c_loadkey NVARCHAR(10), @c_SKU NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @theSQLStmt NVARCHAR(1050)

   SELECT @theSQLStmt = 'SELECT ORDERS.LoadKey, ORDERS.OrderKey, Orderdetail.Sku, SKU.DESCR, '
   SELECT @theSQLStmt = @theSQLStmt+ 'ORDERS.C_company, ORDERS.ConsigneeKey, PACK.CaseCnt, PACK.InnerPack, '
   SELECT @theSQLStmt = @theSQLStmt+ 'PickedQty=SUM(Pickdetail.Qty) '
   SELECT @theSQLStmt = @theSQLStmt+ ', UserID= sUser_sName() FROM ORDERS (NOLOCK) '
   SELECT @theSQLStmt = @theSQLStmt+ 'JOIN ORDERDETAIL (NOLOCK) ON orders.orderkey = ORDERDETAIL.orderkey '
   SELECT @theSQLStmt = @theSQLStmt+ 'JOIN PickDetail (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey '
   SELECT @theSQLStmt = @theSQLStmt+ 'AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber) '
   SELECT @theSQLStmt = @theSQLStmt+ 'JOIN SKU (NOLOCK) ON (SKU.StorerKey = Orders.Storerkey and SKU.Sku = Orderdetail.Sku) '
   SELECT @theSQLStmt = @theSQLStmt+ 'JOIN PACK (NOLOCK) ON PACK.PackKey = OrderDetail.PackKey '
   SELECT @theSQLStmt = @theSQLStmt+ 'JOIN Loc (NOLOCK) ON (pickdetail.loc = Loc.loc ) '
   SELECT @theSQLStmt = @theSQLStmt+ 'WHERE	ORDERDETAIL.loadkey = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_loadkey)) + ''' '
   -- Allow to show all SKU if user leave blank for parameter of SKU 
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_SKU)) <> ''
      SELECT @theSQLStmt = @theSQLStmt+ 'AND ORDERDETAIL.SKU = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_SKU)) + ''' '
   SELECT @theSQLStmt = @theSQLStmt+ 'AND PickDetail.Status < 9 '
   SELECT @theSQLStmt = @theSQLStmt+ 'GROUP BY ORDERS.LoadKey, ORDERS.OrderKey, Orderdetail.Sku, SKU.DESCR, '
   SELECT @theSQLStmt = @theSQLStmt+ 'ORDERS.C_company, ORDERS.ConsigneeKey, PACK.CaseCnt, PACK.InnerPack '
   SELECT @theSQLStmt = @theSQLStmt+ 'HAVING SUM(Orderdetail.QtyAllocated+ Orderdetail.QtyPicked+ Orderdetail.ShippedQty) > 0 '
   SELECT @theSQLStmt = @theSQLStmt+ 'ORDER BY ORDERS.LoadKey, Orderdetail.Sku, ORDERS.ConsigneeKey, ORDERS.OrderKey'   -- 24Aug2005 Ong sos37179
--    SELECT @theSQLStmt = @theSQLStmt+ 'ORDER BY ORDERS.LoadKey, Orderdetail.Sku, ORDERS.OrderKey'
   EXEC(@theSQLStmt)
END

GO