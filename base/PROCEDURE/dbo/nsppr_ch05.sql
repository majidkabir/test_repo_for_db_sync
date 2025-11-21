SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 

/************************************************************************/
/* Stored Procedure: nspPR_CH05                                         */
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
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 27-Sep-2005  MaryVong      Add Header Description and Set ANSI_XXX   */
/* 25-Jul-2014  TLTING     Pass extra parm @c_OtherParms                */
/*																								*/
/************************************************************************/

CREATE PROCEDURE [dbo].[nspPR_CH05]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(10)  ,
@n_uombase int ,
@n_qtylefttofulfill int,  -- new column  
@c_OtherParms NVARCHAR(200) = ''  --Orderinfo4PreAllocation  
AS
BEGIN
   
   DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int
   DECLARE @c_manual NVARCHAR(1)
   DECLARE @c_LimitString NVARCHAR(255) -- To limit the where clause based on the user input
   DECLARE @c_Limitstring1 NVARCHAR(255)  , @c_lottable04label NVARCHAR(20)
   SELECT @b_success= 0, @n_err= 0, @c_errmsg="",@b_debug= 0
   SELECT @c_manual = 'N'

   declare @n_shelflife int
   declare @n_continue int

   DECLARE @c_UOMBase NVARCHAR(10)

   SELECT @c_UOMBase = @n_uombase

   If @d_lottable04 = '1900-01-01'
   Begin
      Select @d_lottable04 = null
   End

   If @d_lottable05 = '1900-01-01'
   Begin
      Select @d_lottable05 = null
   End

   IF @b_debug = 1
   BEGIN
      SELECT "nspPR_CH02 : Before Lot Lookup ....."
      SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03
      SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  , '@c_sku' = @c_sku
      SELECT '@c_storerkey' = @c_storerkey, '@c_facility' = @c_facility
   END

   SELECT @c_LimitString = ''

   IF @c_lottable01 <> ' '
   SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND Lottable01= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)) + "'"

   -- Force the select Fail if no Lottable02 provided 
   IF @c_lottable02 <> ' '
      SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable02= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable02)) + "'"
   ELSE 
      SELECT @c_LimitString = " AND 1 = 2 "

   IF @c_lottable03 <> ' '
      SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable03= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)) + "'"

   IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
      SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable04 = N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable04))) + "'"

   IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
      SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + " AND lottable05= N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable05))) + "'"

   IF @b_debug = 1
   BEGIN
      SELECT 'c_limitstring', @c_limitstring
   END
   SELECT @c_StorerKey = dbo.fnc_RTrim(@c_StorerKey)
   SELECT @c_Sku = dbo.fnc_RTrim(@c_SKU)

   EXEC (' DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  ' +
   ' SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT,  ' +
   ' QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) ' +
   ' FROM LOT (NOLOCK) , LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK) ' +
   ' WHERE LOTXLOCXID.STORERKEY = N''' + @c_storerkey + ''' ' +
   ' AND LOTXLOCXID.SKU = N''' + @c_sku +  ''' '   +
   ' AND LOT.STATUS = "OK" AND LOC.STATUS = "OK" AND ID.STATUS = "OK" And LOC.LocationFlag = "NONE" ' +
   ' AND LOTXLOCXID.ID = ID.ID AND lot.lot = lotattribute.lot ' +
   ' AND LOTXLOCXID.LOT = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' +
   ' AND LOTXLOCXID.LOC = LOC.LOC ' +
   ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_LimitString + ' ' +
   ' AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey '  +
   ' AND SKUxLOC.SKU = LOTxLOCxID.SKU  ' +
   ' AND SKUxLOC.LOC = LOTxLOCxID.LOC  ' +
   ' GROUP BY LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.Lottable02 ' +
   ' HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(LOT.QtyPreAllocated) ) > 0 ' +
   ' ORDER BY LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05, (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(LOT.QtyPreallocated) ) ASC  ')

END

GO