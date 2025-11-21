SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspReconLot                                        */
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

CREATE PROC [dbo].[nspReconLot] AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare cur_1 cursor FAST_FORWARD READ_ONLY
   for
   select orderkey, orderlinenumber, sku, lottable02, lottable03, lottable04
   from orderdetail
   where lottable02 <> ''
   and qtyallocated = 0
   and qtypreallocated = 0
   and shippedqty = 0
   declare @c_key NVARCHAR(10),
   @c_line NVARCHAR(5),
   @c_sku NVARCHAR(20),
   @c_lot2 NVARCHAR(18),
   @c_lot3 NVARCHAR(18),
   @d_lot4 datetime,
   @d_new_lot NVARCHAR(18)
   open cur_1
   fetch NEXT from cur_1 into @c_key, @c_line, @c_sku, @c_lot2, @c_lot3, @d_lot4
   while (@@fetch_status <> -1)
   begin
      set rowcount 1
      select @d_new_lot = lottable02
      from lotattribute a, lot b
      where a.lot = b.lot
      and lottable04 = @d_lot4
      and a.sku = @c_sku
      and lottable03 = @c_lot3
      and qty - qtyallocated <> 0
      order by lottable04
      set rowcount 0
      update orderdetail
      set trafficcop = NULL, lottable02 = @d_new_lot
      where orderkey = @c_key
      and orderlinenumber = @c_line
      and sku = @c_sku
      and lottable04 = @d_lot4
      and lottable03 = @c_lot3
      fetch next from cur_1 into @c_key, @c_line, @c_sku, @c_lot2, @c_lot3, @d_lot4
   end
   close cur_1
   deallocate cur_1
END

GO