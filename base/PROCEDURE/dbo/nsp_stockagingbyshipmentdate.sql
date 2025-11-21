SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_StockAgingByShipmentDate                       */
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
/************************************************************************/

CREATE PROCEDURE [dbo].[nsp_StockAgingByShipmentDate](
@c_storerkey NVARCHAR(15),
@c_fr_skugroup NVARCHAR(10),
@c_to_skugroup NVARCHAR(10),
@c_fr_sku NVARCHAR(20),
@c_to_sku NVARCHAR(20))
AS
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_storer NVARCHAR(15), @c_company NVARCHAR(20),
   @c_product_group NVARCHAR(10),
   @c_product NVARCHAR(20),
   @c_descr NVARCHAR(60),
   @c_packkey NVARCHAR(10),
   @d_received_date datetime,
   @i_total_qty int,
   @i_received_qty int,
   @c_lot NVARCHAR(10)

   declare @i_lesstwo int,
   @i_twomth int,
   @i_threemth int,
   @i_fourmth int,
   @i_fivemth int,
   @i_sixmth int,
   @i_moresix int,
   @i_morenine int,
   @i_moretwelve int,
   @i_days_apart int


   create table #temp_age
   (
   storerkey NVARCHAR(15) null,
   skugroup NVARCHAR(20)  null,
   sku NVARCHAR(20)  null,
   lot NVARCHAR(10) null,
   descr NVARCHAR(60) null,
   packkey NVARCHAR(10) null,
   totalqty int null,
   expiredqty int null,
   lesstwo int null,
   twomth int null,
   threemth int null,
   fourmth int null,
   fivemth int null,
   sixmth int null,
   moresix int null,
   morenine int null,
   moretwelve int null
   )


   /** (1) cursor for getting the total quantity for each sku **/
   declare sku_stock cursor
   local dynamic
   for
   SELECT STORER.StorerKey, STORER.Company,
   SKU.SKUGROUP,
   LOTxLOCxID.Sku,
   SKU.DESCR,
   SKU.PACKKey,
   LOTXLOCXID.Lot,
   sum(lotxlocxid.qty)
   FROM SKU (nolock),
   STORER (nolock),
   LOTxLOCxID (nolock),
   LOTATTRIBUTE (nolock)
   WHERE ( STORER.StorerKey = SKU.StorerKey ) and
   ( LOTxLOCxID.StorerKey = SKU.StorerKey ) and
   ( LOTxLOCxID.Sku = SKU.Sku ) and
   ( LOTxLOCxID.StorerKey = LOTATTRIBUTE.StorerKey ) and
   ( LOTxLOCxID.Sku = LOTATTRIBUTE.Sku ) and
   ( LOTxLOCxID.Lot = LOTATTRIBUTE.Lot ) and
   ( LOTxLOCxID.StorerKey = @c_storerkey ) AND
   ( SKU.SKUGROUP between @c_fr_skugroup and @c_to_skugroup ) AND
   ( LOTxLOCxID.Sku between @c_fr_sku and @c_to_sku )
   GROUP BY STORER.StorerKey, STORER.Company,
   SKU.SKUGROUP,
   LOTxLOCxID.Sku,
   SKU.DESCR,
   SKU.PACKKey,
   LOTXLOCXID.Lot

   open sku_stock

   fetch next from sku_stock into 	@c_storer, @c_company,
   @c_product_group,
   @c_product,
   @c_descr,
   @c_packkey,
   @c_lot,
   @i_total_qty


   while (@@fetch_status=0)
   begin

      select	@i_received_qty=null,
      @i_lesstwo=null,
      @i_twomth=null,
      @i_threemth=null,
      @i_fourmth=null,
      @i_fivemth=null,
      @i_sixmth=null,
      @i_moresix=null,
      @i_morenine=null,
      @i_moretwelve=null

      SELECT @d_received_date=receiptdetail.datereceived,
      @i_received_qty=sum(receiptdetail.qtyreceived)
      FROM SKU (nolock),
      STORER (nolock),
      LOTxLOCxID (nolock),
      LOTATTRIBUTE (nolock),
      Receiptdetail (nolock)
      WHERE ( STORER.StorerKey = SKU.StorerKey ) and
      ( LOTxLOCxID.StorerKey = SKU.StorerKey ) and
      ( LOTxLOCxID.Sku = SKU.Sku ) and
      ( LOTxLOCxID.StorerKey = LOTATTRIBUTE.StorerKey ) and
      ( LOTxLOCxID.Sku = LOTATTRIBUTE.Sku ) and
      ( LOTxLOCxID.Lot = LOTATTRIBUTE.Lot ) and
      ( LOTxLOCxID.StorerKey = @c_storer ) AND
      ( SKU.SKUGROUP = @c_product_group ) AND
      ( LOTxLOCxID.Sku = @c_product ) AND
      ( LOTXLOCXID.Lot = @c_lot) and
      (receiptdetail.sku=sku.sku) and
      ( receiptdetail.datereceived < getdate() )
      GROUP BY receiptdetail.datereceived


      if (@@fetch_status=0)
      begin
         Select @i_days_apart=datediff(day,@d_received_date,getdate())

         if @i_days_apart < 60
         select @i_lesstwo = @i_received_qty

         if @i_lesstwo=0
         select @i_lesstwo=null

      else
         if ((@i_days_apart >= 60 ) and (@i_days_apart < 90 ))

         select @i_twomth=@i_received_qty

         if @i_twomth=0
         select @i_twomth=null

      else
         if ((@i_days_apart >= 90 ) and (@i_days_apart < 120))

         select @i_threemth=@i_received_qty

         if @i_threemth=0
         select @i_threemth=null

      else
         if ((@i_days_apart >= 120 ) and (@i_days_apart < 150))

         select @i_fourmth=@i_received_qty

         if @i_fourmth=0
         select @i_fourmth=null

      else
         if ((@i_days_apart >= 150 ) and (@i_days_apart < 180))

         select @i_fivemth=@i_received_qty

         if @i_fivemth=0
         select @i_fivemth=null

      else
         if ((@i_days_apart >= 180) and (@i_days_apart < 210))

         select @i_sixmth=@i_received_qty

         if @i_sixmth=0
         select @i_sixmth=null

         -- another if statement for qty more than 6, 9 , 12 months
         if ((@i_days_apart >= 180) and (@i_days_apart < 270))
         select @i_moresix=@i_received_qty

      else
         if ((@i_days_apart >= 270) and (@i_days_apart < 360))

         select @i_morenine=@i_received_qty

      else
         if @i_days_apart > 360

         select @i_moretwelve=@i_received_qty


         insert into #temp_age
         values(	@c_storer,
         @c_product_group,
         @c_product,
         @c_lot,
         @c_descr,
         @c_packkey,
         @i_total_qty,
         @i_received_qty,
         @i_lesstwo,
         @i_twomth,
         @i_threemth,
         @i_fourmth,
         @i_fivemth,
         @i_sixmth,
         @i_moresix,
         @i_morenine,
         @i_moretwelve)

      end


      fetch next from sku_stock into 	@c_storer, @c_company,
      @c_product_group,
      @c_product,
      @c_descr,
      @c_packkey,
      @c_lot,
      @i_total_qty
   end


   --close stock_age
   --deallocate stock_age

   close sku_stock
   deallocate sku_stock


   select * from #temp_age

   drop table #temp_age

end

GO