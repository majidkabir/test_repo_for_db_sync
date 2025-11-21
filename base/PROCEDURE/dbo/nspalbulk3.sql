SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALBULK3                                         */
/* Creation Date: 05-Aug-2002                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-May-2011  Ung           SOS 213805. Filter by LocLevel,           */
/*                            Sort by LogicalLocation                   */
/*                                                                      */
/************************************************************************/
CREATE PROC    [dbo].[nspALBULK3]
   @c_LoadKey    NVARCHAR(10),
   @c_Facility   NVARCHAR(5),
   @c_StorerKey  NVARCHAR(15),
   @c_SKU        NVARCHAR(20),
   @c_UOM        NVARCHAR(10),
   @c_HostWHCode NVARCHAR(10),
   @n_UOMBase    INT,
   @n_QtyLeftToFulfill INT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int,
           @c_Manual NVARCHAR(1),
           @c_LimitString NVARCHAR(MAX),
           @n_ShelfLife int,
           @c_SQL NVARCHAR(max)

   DECLARE
           @b_Success    INT
          ,@n_err        INT
          ,@c_errmsg     NVARCHAR(250)


   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED -
                             LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen),
             '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> 'HOLD')
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> 'HOLD')
      JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT
      JOIN SKUxLOC s (NOLOCK) ON s.StorerKey = LOTxLOCxID.StorerKey AND s.Sku = LOTxLOCxID.Sku AND s.Loc = LOTxLOCxID.Loc
      JOIN SKU (NOLOCK) ON SKU.StorerKey = s.StorerKey AND SKU.Sku = s.Sku
      WHERE LOC.LocationFlag <> 'HOLD'
      AND LOC.LocationFlag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND LOC.Facility = @c_Facility
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU
      AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen >= @n_UOMBase
      AND s.LocationType NOT IN ('PICK','CASE')
      AND LOC.LocLevel <> 1
      ORDER BY LOC.LogicalLocation, QTYAVAILABLE

END

GO