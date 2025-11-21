SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRstdC2                                         */
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

CREATE PROC [dbo].[nspPRstdC2]   -- rename from IDSPH(ULP):nspPRstd02
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@c_lottable04 datetime ,
@c_lottable05 datetime ,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int
AS
BEGIN
	      

   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTXLOCXID.STORERKEY,LOTXLOCXID.SKU,LOTXLOCXID.LOT ,
      QTYAVAILABLE = (LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM  LOTXLOCXID (NOLOCK), LOC (NOLOCK), LOT (NOLOCK)
      WHERE LOTXLOCXID.LOT = @c_lot
      AND   LOTXLOCXID.LOC = LOC.LOC
      AND   LOTXLOCXID.LOT = LOT.LOT
      AND   LOC.Facility = @c_facility
      AND   LOC.Locationtype IN ('CASE', 'PICK')
      ORDER BY LOTXLOCXID.LOT
   END
ELSE
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTXLOCXID.STORERKEY,LOTXLOCXID.SKU,LOTXLOCXID.LOT  ,
      QTYAVAILABLE = (LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QTYONHOLD)
      FROM LOTXLOCXID (NOLOCK), LOC (NOLOCK), LOT (NOLOCK)
      WHERE LOTXLOCXID.STORERKEY = @c_storerkey
      AND LOTXLOCXID.LOT = LOT.LOT
      AND LOTXLOCXID.LOC = LOC.LOC
      AND   LOC.Facility = @c_facility
      AND LOTXLOCXID.SKU = @c_sku
      AND LOT.STATUS = "OK"
      AND (LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QTYONHOLD) > 0
      AND LOC.Locationtype IN ('CASE', 'PICK')
      ORDER BY LOTXLOCXID.LOT
   END
END

GO