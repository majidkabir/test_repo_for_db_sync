SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_stkonhand_by_batch                             */
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

CREATE PROCedure [dbo].[nsp_stkonhand_by_batch](
@c_storer_start NVARCHAR(15),
@c_storer_end NVARCHAR(15),
@c_loc_start NVARCHAR(10),
@c_loc_end NVARCHAR(10),
@c_sku_start NVARCHAR(20),
@c_sku_end NVARCHAR(20)
)
as
begin
   /*
   Author : Jacob Yong
   Date   : 14-09-2000
   Descr  : To replace IDSM19 which does NOT show SKUs without pallet ID. This report shows all SKUs
   with OR without pallet IDs and are not held in InventoryHold table with hold="1"
   Assumption : SKUs that have no pallet IDs are DEFINITELY NOT in the InventoryHold table.
   */

   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   create table #temp(
   storerkey NVARCHAR(15) null,
   sku NVARCHAR(20) null,
   descr NVARCHAR(60) null,
   uom NVARCHAR(10) null,
   qtyonhand int null,
   qtyallocated int null,
   qtyavailable int null,
   batchno NVARCHAR(18) null,
   expirydate datetime null
   )


   declare @c_sku NVARCHAR(20),
   @c_descr NVARCHAR(60),
   @c_uom NVARCHAR(10),
   @i_onhand int,
   @i_allocated int,
   @i_available int,
   @c_batch NVARCHAR(18),
   @d_expiry datetime,
   @c_id NVARCHAR(18),
   @c_id_hold NVARCHAR(18),
   @f_casecnt float(8),
   @c_packuom1 NVARCHAR(10),
   @f_innerpack float(8),
   @c_packuom2 NVARCHAR(10),
   @f_qty float(8),
   @c_packuom3 NVARCHAR(10),
   @f_pallet float(8),
   @c_packuom4 NVARCHAR(10),
   @f_cube float(8),
   @c_packuom5 NVARCHAR(10),
   @f_grosswgt float(8),
   @c_packuom6 NVARCHAR(10),
   @f_netwgt float(8),
   @c_packuom7 NVARCHAR(10),
   @f_otherunit1 float(8),
   @c_packuom8 NVARCHAR(10),
   @f_otherunit2 float(8),
   @c_packuom9 NVARCHAR(10),
   @c_storer NVARCHAR(15)

   declare sku_cur cursor FAST_FORWARD READ_ONLY
   for
   select a.sku,
   b.descr,
   a.qty,
   a.qtyallocated,
   a.qty-a.qtyallocated-a.qtypicked,
   a.id,
   c.casecnt,
   c.packuom1,
   c.innerpack,
   c.packuom2,
   c.qty,
   c.packuom3,
   c.pallet,
   c.packuom4,
   c.cube,
   c.packuom5,
   c.grosswgt,
   c.packuom6,
   c.netwgt,
   c.packuom7,
   c.otherunit1,
   c.packuom8,
   c.otherunit2,
   c.packuom9,
   d.lottable01,
   d.lottable04,
   a.storerkey
   from lotxlocxid a (nolock), sku b (nolock), pack c (nolock), lotattribute d (nolock)
   where a.sku between @c_sku_start and @c_sku_end
   and a.storerkey between @c_storer_start and @c_storer_end
   and a.loc between @c_loc_start and @c_loc_end
   and a.sku = b.sku
   and b.packkey = c.packkey
   and a.lot=d.lot
   and a.qty>0


   open sku_cur

   fetch next from sku_cur into @c_sku,
   @c_descr,
   @i_onhand,
   @i_allocated,
   @i_available,
   @c_id,
   @f_casecnt,
   @c_packuom1,
   @f_innerpack,
   @c_packuom2,
   @f_qty,
   @c_packuom3,
   @f_pallet,
   @c_packuom4,
   @f_cube,
   @c_packuom5,
   @f_grosswgt,
   @c_packuom6,
   @f_netwgt,
   @c_packuom7,
   @f_otherunit1,
   @c_packuom8,
   @f_otherunit2,
   @c_packuom9,
   @c_batch,
   @d_expiry,
   @c_storer

   while (@@fetch_status=0)
   begin
      /* To determine UOM */
      if @f_casecnt=1
      select @c_uom=@c_packuom1
   else
      if @f_innerpack=1
      select @c_uom=@c_packuom2
   else
      if @f_qty=1
      select @c_uom=@c_packuom3
   else
      if @f_pallet=1         select @c_uom=@c_packuom4
   else
      if @f_cube=1
      select @c_uom=@c_packuom5
   else
      if @f_grosswgt=1
      select @c_uom=@c_packuom6
   else
      if @f_netwgt=1
      select @c_uom=@c_packuom7
   else
      if @f_otherunit1=1
      select @c_uom=@c_packuom8
   else
      if @f_otherunit2=1
      select @c_uom=@c_packuom9
      /* end of determining UOM */

      if (@c_id="") or (len(@c_id)=0)
      insert into #temp
      values(@c_storer, @c_sku, @c_descr, @c_uom, @i_onhand, @i_allocated, @i_available, @c_batch, @d_expiry)
   else
      begin
         select @c_id_hold=id from inventoryhold (nolock)
         where id=@c_id
         and hold="1"

         if @@rowcount=0
         insert into #temp
         values(@c_storer, @c_sku, @c_descr, @c_uom, @i_onhand, @i_allocated, @i_available, @c_batch, @d_expiry)
      end

      fetch next from sku_cur into @c_sku,
      @c_descr,
      @i_onhand,
      @i_allocated,
      @i_available,
      @c_id,
      @f_casecnt,
      @c_packuom1,
      @f_innerpack,
      @c_packuom2,
      @f_qty,
      @c_packuom3,
      @f_pallet,
      @c_packuom4,
      @f_cube,
      @c_packuom5,
      @f_grosswgt,
      @c_packuom6,
      @f_netwgt,
      @c_packuom7,
      @f_otherunit1,
      @c_packuom8,
      @f_otherunit2,
      @c_packuom9,
      @c_batch,
      @d_expiry,
      @c_storer

   end

   select storerkey,
   sku,
   descr,
   uom,
   qtyonhand=sum(qtyonhand),
   qtyallocated=sum(qtyallocated),
   qtyavailable=sum(qtyavailable),
   batchno,
   expirydate
   from #temp
   group by storerkey,
   sku,
   descr,
   uom,
   batchno,
   expirydate

   drop table #temp

   close sku_cur
   deallocate sku_cur
end

GO