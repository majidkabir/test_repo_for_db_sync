SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_PrintSortList07                                */
/* Creation Date: 12-Jan-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose:  Create Indent Sort List for IDSPH WTC (SOS45044)           */
/*           Note: Copy from nsp_GetPickSlipOrders20 and modified       */
/*                                                                      */
/* Input Parameters:  @c_loadkey - Loadkey                              */
/*                    @c_SKU - Sku (Optional)                           */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_sortlist07                         */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 2007-07-16  TLTING      SQL2005, Status = 9 put '9'                  */
/* 2009-02-05  Rick Liew   Add lottable02 and lottable04 for SOS#127813 */
/************************************************************************/

CREATE PROC [dbo].[nsp_PrintSortList07] (@c_Loadkey NVARCHAR(10), @c_SKU NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SQLStmt NVARCHAR(4000)

   SELECT @c_SQLStmt = ''
   
   SELECT @c_SQLStmt = 'SELECT PickDetail.PickSlipNo, Orders.LoadKey, Orders.Orderkey, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'OrderDetail.Sku, SKU.DESCR, Orders.C_Company, Orders.ConsigneeKey, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'PickedQty = SUM(PickDetail.Qty) , '
   SELECT @c_SQLStmt = @c_SQLStmt + 'UOM = CASE PickDetail.UOM '
   SELECT @c_SQLStmt = @c_SQLStmt + 'WHEN ''1'' THEN ''Pallet'' '
   SELECT @c_SQLStmt = @c_SQLStmt + 'WHEN ''2'' THEN ''Case'' '
   SELECT @c_SQLStmt = @c_SQLStmt + 'WHEN ''3'' THEN ''InnerPack'' '
   SELECT @c_SQLStmt = @c_SQLStmt + 'WHEN ''6'' THEN ''Each'' '
   SELECT @c_SQLStmt = @c_SQLStmt + 'END, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'PACK.Pallet, PACK.CaseCnt, PACK.InnerPack, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'STORERSODEFAULT.XDockLane, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'CONVERT(NVARCHAR(60), Orders.Notes), '
   SELECT @c_SQLStmt = @c_SQLStmt + 'UserID = sUser_sName() ,'
   SELECT @c_SQLStmt = @c_SQLStmt + 'LA.Lottable02 ,'
   SELECT @c_SQLStmt = @c_SQLStmt + 'LA.Lottable04 '
   SELECT @c_SQLStmt = @c_SQLStmt + 'FROM Orders (NOLOCK) '
   SELECT @c_SQLStmt = @c_SQLStmt + 'JOIN OrderDetail (NOLOCK) ON Orders.Orderkey = OrderDetail.Orderkey '
   SELECT @c_SQLStmt = @c_SQLStmt + 'JOIN PickDetail (NOLOCK) ON (PickDetail.Orderkey = OrderDetail.Orderkey AND ' 
   SELECT @c_SQLStmt = @c_SQLStmt + 'PickDetail.orderlinenumber = OrderDetail.orderlinenumber) '
   SELECT @c_SQLStmt = @c_SQLStmt + 'JOIN SKU (NOLOCK) ON (SKU.StorerKey = Orders.Storerkey AND ' 
   SELECT @c_SQLStmt = @c_SQLStmt + 'SKU.Sku = OrderDetail.Sku) '
   SELECT @c_SQLStmt = @c_SQLStmt + 'JOIN PACK (NOLOCK) ON PACK.PackKey = OrderDetail.PackKey '
   SELECT @c_SQLStmt = @c_SQLStmt + 'JOIN LOC (NOLOCK) ON (PickDetail.Loc = Loc.Loc ) '
   SELECT @c_SQLStmt = @c_SQLStmt + 'JOIN CODELKUP (NOLOCK) ON (Orders.Type = CODELKUP.Code AND ' 
   SELECT @c_SQLStmt = @c_SQLStmt + 'CODELKUP.Listname = ''WTCORDTYPE'' AND '
   SELECT @c_SQLStmt = @c_SQLStmt + 'CODELKUP.Short = ''BATCH'' ) '
   SELECT @c_SQLStmt = @c_SQLStmt + 'LEFT OUTER JOIN STORER (NOLOCK) '
   SELECT @c_SQLStmt = @c_SQLStmt + 'ON Storer.Storerkey = Orders.Consigneekey ' 
   SELECT @c_SQLStmt = @c_SQLStmt + 'LEFT OUTER JOIN STORERSODEFAULT (NOLOCK) '
   SELECT @c_SQLStmt = @c_SQLStmt + 'ON Storer.Storerkey = STORERSODEFAULT.Storerkey '
   SELECT @c_SQLStmt = @c_SQLStmt + 'LEFT OUTER JOIN LOTATTRIBUTE LA (NOLOCK) '
   SELECT @c_SQLStmt = @c_SQLStmt + 'ON (LA.Storerkey = Pickdetail.Storerkey AND '
   SELECT @c_SQLStmt = @c_SQLStmt + 'LA.SKU = Pickdetail.SKU AND LA.Lot = Pickdetail.Lot )'
   SELECT @c_SQLStmt = @c_SQLStmt + 'WHERE OrderDetail.Loadkey = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Loadkey)) + ''' '

   -- Allow to show all SKU if user leave blank for parameter of SKU 
   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_SKU)) <> ''
      SELECT @c_SQLStmt = @c_SQLStmt + 'AND OrderDetail.SKU = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_SKU)) + ''' '

   SELECT @c_SQLStmt = @c_SQLStmt + 'AND PickDetail.Status < ''9'' '       -- SQL2005 put ' in status check
   SELECT @c_SQLStmt = @c_SQLStmt + 'GROUP BY PickDetail.PickSlipNo, Orders.LoadKey, Orders.Orderkey, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'OrderDetail.Sku, SKU.DESCR, Orders.C_Company, Orders.ConsigneeKey, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'CASE PickDetail.UOM '
   SELECT @c_SQLStmt = @c_SQLStmt + 'WHEN ''1'' THEN ''Pallet'' '
   SELECT @c_SQLStmt = @c_SQLStmt + 'WHEN ''2'' THEN ''Case'' '
   SELECT @c_SQLStmt = @c_SQLStmt + 'WHEN ''3'' THEN ''InnerPack'' '
   SELECT @c_SQLStmt = @c_SQLStmt + 'WHEN ''6'' THEN ''Each'' '
   SELECT @c_SQLStmt = @c_SQLStmt + 'END, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'PACK.Pallet, PACK.CaseCnt, PACK.InnerPack, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'STORERSODEFAULT.XDockLane, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'CONVERT(NVARCHAR(60), Orders.Notes), '
   SELECT @c_SQLStmt = @c_SQLStmt + 'LA.Lottable02 ,'
   SELECT @c_SQLStmt = @c_SQLStmt + 'LA.Lottable04 '
   SELECT @c_SQLStmt = @c_SQLStmt + 'HAVING SUM(OrderDetail.QtyAllocated+ OrderDetail.QtyPicked+ OrderDetail.ShippedQty) > 0 '
   SELECT @c_SQLStmt = @c_SQLStmt + 'ORDER BY PickDetail.PickSlipNo, Orders.LoadKey, OrderDetail.Sku, PickDetail.UOM, '
   SELECT @c_SQLStmt = @c_SQLStmt + 'Orders.ConsigneeKey, Orders.Orderkey '

   -- SELECT LEN(@c_SQLStmt)
   EXEC(@c_SQLStmt)
END

GO