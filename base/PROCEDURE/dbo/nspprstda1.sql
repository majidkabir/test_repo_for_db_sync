SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nspPRstdA1                                         */
/* Creation Date: 10-Feb-2005                                           */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 10-Feb-2005       1.0      Initial Version								   */
/************************************************************************/
CREATE PROC    [dbo].[nspPRstdA1] -- Rename from IDSMY:nspPRstd01
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN

DECLARE @n_StorerMinShelfLife int

IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
BEGIN

/* Get Storer Minimum Shelf Life */
/*
SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
FROM Sku (nolock), Storer (nolock), Lot (nolock)
WHERE Lot.Lot = @c_lot
AND Lot.Sku = Sku.Sku
AND Sku.Storerkey = Storer.Storerkey
*/

DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
WHERE LOT.LOT = LOTATTRIBUTE.LOT  
AND LOTXLOCXID.Lot = LOT.LOT
AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
AND LOTXLOCXID.LOC = LOC.LOC
AND LOC.Facility = @c_facility
AND LOT.LOT = @c_lot 
-- AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
ORDER BY Lotattribute.Lottable04, Lot.Lot

END
ELSE
BEGIN
/* Get Storer Minimum Shelf Life */
/*
   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
   FROM Sku (nolock), Storer (nolock)
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey   
   AND Sku.Storerkey = Storer.Storerkey
*/

   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT  ,
QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD)
FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
WHERE LOT.LOT = LOTATTRIBUTE.LOT  
AND LOTXLOCXID.Lot = LOT.LOT
AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
AND LOTXLOCXID.LOC = LOC.LOC
AND LOC.Facility = @c_facility
AND LOT.STORERKEY = @c_storerkey
AND LOT.SKU = @c_sku
AND LOT.STATUS = "OK"
AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - QTYONHOLD) > 0
-- AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
ORDER BY Lotattribute.Lottable04, LOT.Lot

END
END


GO