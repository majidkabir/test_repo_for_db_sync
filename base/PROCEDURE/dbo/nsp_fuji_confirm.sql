SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_fuji_confirm                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[nsp_fuji_confirm] AS
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_extern NVARCHAR(30),
   @c_consign NVARCHAR(15),
   @d_orderdate datetime,
   @d_deliverdate datetime,
   @c_orderkey NVARCHAR(10),
   @c_mbolkey NVARCHAR(10),
   @c_company NVARCHAR(45),
   @c_sku NVARCHAR(20),
   @c_orderline NVARCHAR(5),
   @i_originalqty int,
   @c_uom NVARCHAR(10),
   @i_shippedqty int,
   @c_header NVARCHAR(3)

   select @c_header = "DSH"

   declare ord_cur cursor FAST_FORWARD READ_ONLY
   for
   select orderkey, externorderkey, consigneekey, orderdate, deliverydate from orders
   where storerkey="FUJI"
   order by orderkey

   open ord_cur

   fetch next from ord_cur into @c_orderkey, @c_extern, @c_consign, @d_orderdate, @d_deliverdate

   while (@@fetch_status=0)
   begin
      --select "DSH", @c_extern, @c_consign, convert(char(8),@d_orderdate,112), convert(char(8),@d_deliverdate,112)
      select @c_header, @c_extern, @c_consign, convert(char(8),@d_orderdate,112), convert(char(8),@d_deliverdate,112)
      declare orddet cursor FAST_FORWARD READ_ONLY
      for
      SELECT MBOLDETAIL.MbolKey,
      ORDERS.C_Company,
      ORDERDETAIL.OrderLineNumber,
      ORDERDETAIL.Sku,
      ORDERDETAIL.OriginalQty,
      ORDERDETAIL.UOM,
      ORDERDETAIL.ShippedQty
      FROM ORDERDETAIL,
      ORDERS,
      MBOLDETAIL
      WHERE ( ORDERDETAIL.OrderKey = ORDERS.OrderKey ) and
      ( ORDERS.OrderKey = MBOLDETAIL.OrderKey )  and
      ( orders.orderkey = @c_orderkey ) and
      ( orders.storerkey = "Fuji" )

      open orddet

      fetch next from orddet into @c_mbolkey, @c_company, @c_orderline, @c_sku, @i_originalqty, @c_uom, @i_shippedqty

      while (@@fetch_status=0)
      begin

         --select "CSP", @c_extern, @c_orderkey, @c_mbolkey, convert(char(8),@d_orderdate,112), convert(char(8),@d_deliverdate,112), @c_consign, @c_company, @c_orderline, @c_sku, @i_originalqty, @c_uom, @i_shippedqty, @i_originalqty-@i_shippedqty
         fetch next from orddet into @c_mbolkey, @c_company, @c_orderline, @c_sku, @i_originalqty, @c_uom, @i_shippedqty
      end

      close orddet
      deallocate orddet

      fetch next from ord_cur into @c_orderkey, @c_extern, @c_consign, @d_orderdate, @d_deliverdate
   end

   close ord_cur
   deallocate ord_cur
end

GO