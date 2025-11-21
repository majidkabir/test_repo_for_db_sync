SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRstdA2                                         */
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
CREATE PROC  [dbo].[nspPRstdA2]  -- Rename from IDSMY:nspPRstd02
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

IF ISNULL(RTRIM(@c_lot),'') <> ''
BEGIN
    DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY 
    FOR
        SELECT LOT.STORERKEY
              ,LOT.SKU
              ,LOT.LOT
              ,QTYAVAILABLE = (
                   LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED
               )
        FROM   LOT(NOLOCK)
              ,LOTXLOCXID(NOLOCK)
              ,LOC(NOLOCK)
        WHERE  LOTXLOCXID.Lot = LOT.LOT
               AND LOTXLOCXID.LOC = LOC.LOC
               AND LOC.Facility = @c_facility
               AND LOT.LOT = @c_lot
        ORDER BY
               LOT.LOT
END
ELSE
BEGIN
    DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY 
    FOR
        SELECT LOT.STORERKEY
              ,LOT.SKU
              ,LOT.LOT
              ,QTYAVAILABLE = (
                   LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED- QTYONHOLD
               )
        FROM   LOT(NOLOCK)
              ,LOTXLOCXID(NOLOCK)
              ,LOC(NOLOCK)
        WHERE  LOTXLOCXID.Lot = LOT.LOT
               AND LOTXLOCXID.LOC = LOC.LOC
               AND LOC.Facility = @c_facility
               AND LOT.STORERKEY = @c_storerkey
               AND LOT.SKU = @c_sku
               AND LOT.STATUS = "OK"
               AND (
                       LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED- QTYONHOLD
                   )>0
        ORDER BY
               LOT.LOT
END
END


GO